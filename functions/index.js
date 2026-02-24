const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ===== SAFE SEQUENTIAL ID GENERATOR =====
async function generateSequentialId(prefix) {
  const counterRef = db.collection("counters").doc(prefix);

  const newId = await db.runTransaction(async (transaction) => {
    const counterDoc = await transaction.get(counterRef);

    let currentNumber = 0;

    if (counterDoc.exists) {
      currentNumber = counterDoc.data().lastNumber || 0;
    }

    const nextNumber = currentNumber + 1;

    transaction.set(counterRef, { lastNumber: nextNumber }, { merge: true });

    return prefix + String(nextNumber).padStart(3, "0");
  });

  return newId;
}




/**
 * AUTO LOCK ATTENDANCE AT 4:00 PM (Asia/Kolkata)
 * Locks all attendance records for the current day across all schools and classes
 * Prevents further editing after the deadline
 */
exports.autoLockAttendance = functions
  .region("asia-south1")
  .pubsub.schedule("0 16 * * *") // 4:00 PM daily
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    try {
      const today = new Date();
      const year = today.getFullYear();
      const month = String(today.getMonth() + 1).padStart(2, "0");
      const day = String(today.getDate()).padStart(2, "0");
      const dateString = `${year}-${month}-${day}`; // YYYY-MM-DD

      console.log(`Starting auto-lock for date: ${dateString}`);

      let totalLocked = 0;
      let totalSkipped = 0;

      // Get all schools
      const schoolsSnapshot = await db.collection("schools").get();
      console.log(`Found ${schoolsSnapshot.size} schools`);

      for (const schoolDoc of schoolsSnapshot.docs) {
        const schoolId = schoolDoc.id;

        // Get all class-section combinations in attendance collection
        const attendanceSnapshot = await db
          .collection("schools")
          .doc(schoolId)
          .collection("attendance")
          .get();

        console.log(`School ${schoolId}: Found ${attendanceSnapshot.size} class-sections`);

        for (const classSectionDoc of attendanceSnapshot.docs) {
          const classSectionId = classSectionDoc.id; // e.g., "5_A" or "Class_5A"

          // Path: schools/{schoolId}/attendance/{classSectionId}/days/{dateString}
          const dayDocRef = db
            .collection("schools")
            .doc(schoolId)
            .collection("attendance")
            .doc(classSectionId)
            .collection("days")
            .doc(dateString);

          const dayDocSnap = await dayDocRef.get();

          if (dayDocSnap.exists) {
            const data = dayDocSnap.data();
            const meta = data.meta || {};

            // Only lock if not already locked and not a holiday
            if (!meta.locked && !meta.isHoliday) {
              await dayDocRef.update({
                "meta.locked": true,
                "meta.lockedAt": admin.firestore.FieldValue.serverTimestamp(),
                "meta.lockedBy": "system_auto_lock",
              });

              totalLocked++;
              console.log(`Locked: ${schoolId}/${classSectionId}/${dateString}`);
            } else {
              totalSkipped++;
              console.log(`Skipped: ${schoolId}/${classSectionId}/${dateString} (already locked or holiday)`);
            }
          } else {
            console.log(`No attendance record found for ${schoolId}/${classSectionId}/${dateString}`);
          }
        }
      }

      console.log(`Auto-lock completed. Locked: ${totalLocked}, Skipped: ${totalSkipped}`);
      return { success: true, locked: totalLocked, skipped: totalSkipped };

    } catch (error) {
      console.error("Error in autoLockAttendance:", error);
      throw error;
    }
  });

/**
 * MANUAL UNLOCK FUNCTION (Admin Only)
 * Call this function to unlock attendance for a specific date
 * 
 * Example usage:
 * firebase functions:call unlockAttendance --data '{"schoolId":"school_001","classSectionId":"5_A","date":"2026-02-21"}'
 */
exports.unlockAttendance = functions
  .region("asia-south1")
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    // Verify admin role
    const uid = context.auth.uid;
    const userDoc = await db
      .collection("schools")
      .doc(data.schoolId)
      .collection("users")
      .doc(uid)
      .get();

    if (!userDoc.exists || userDoc.data().role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can unlock attendance"
      );
    }

    const { schoolId, classSectionId, date } = data;

    if (!schoolId || !classSectionId || !date) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "schoolId, classSectionId, and date are required"
      );
    }

    try {
      const dayDocRef = db
        .collection("schools")
        .doc(schoolId)
        .collection("attendance")
        .doc(classSectionId)
        .collection("days")
        .doc(date);

      await dayDocRef.update({
        "meta.locked": false,
        "meta.unlockedAt": admin.firestore.FieldValue.serverTimestamp(),
        "meta.unlockedBy": uid,
      });

      console.log(`Admin ${uid} unlocked ${schoolId}/${classSectionId}/${date}`);
      return { success: true, message: "Attendance unlocked successfully" };

    } catch (error) {
      console.error("Error unlocking attendance:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  });

/**
 * AUTO-GENERATE MONTHLY SUMMARIES
 * Runs on the 1st of every month at 1:00 AM
 * Calculates attendance percentages for the previous month
 */
exports.generateMonthlySummaries = functions
  .region("asia-south1")
  .pubsub.schedule("0 1 1 * *") // 1st of every month at 1:00 AM
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    try {
      const now = new Date();
      const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const year = lastMonth.getFullYear();
      const month = String(lastMonth.getMonth() + 1).padStart(2, "0");
      const monthKey = `${year}-${month}`;

      console.log(`Generating monthly summaries for: ${monthKey}`);

      const schoolsSnapshot = await db.collection("schools").get();

      for (const schoolDoc of schoolsSnapshot.docs) {
        const schoolId = schoolDoc.id;
        const attendanceSnapshot = await db
          .collection("schools")
          .doc(schoolId)
          .collection("attendance")
          .get();

        for (const classSectionDoc of attendanceSnapshot.docs) {
          const classSectionId = classSectionDoc.id;

          // Get all days for the month
          const daysSnapshot = await db
            .collection("schools")
            .doc(schoolId)
            .collection("attendance")
            .doc(classSectionId)
            .collection("days")
            .where("meta.date", ">=", admin.firestore.Timestamp.fromDate(lastMonth))
            .where("meta.date", "<", admin.firestore.Timestamp.fromDate(now))
            .get();

          // Aggregate student-wise data
          const studentData = {};

          for (const dayDoc of daysSnapshot.docs) {
            const data = dayDoc.data();
            const meta = data.meta || {};
            const students = data.students || {};

            if (meta.isHoliday) continue;

            for (const [studentId, studentInfo] of Object.entries(students)) {
              if (!studentData[studentId]) {
                studentData[studentId] = {
                  present: 0,
                  absent: 0,
                  studentName: studentInfo.studentName,
                  rollNumber: studentInfo.rollNumber,
                };
              }

              if (studentInfo.status === "P") {
                studentData[studentId].present++;
              } else if (studentInfo.status === "A") {
                studentData[studentId].absent++;
              }
            }
          }

          // Save monthly summary
          const summaryRef = db
            .collection("schools")
            .doc(schoolId)
            .collection("attendance_summary")
            .doc(classSectionId)
            .collection("months")
            .doc(monthKey);

          const summaryData = {};
          for (const [studentId, stats] of Object.entries(studentData)) {
            const total = stats.present + stats.absent;
            const percentage = total > 0 ? (stats.present / total) * 100 : 0;

            summaryData[studentId] = {
              totalPresent: stats.present,
              totalAbsent: stats.absent,
              percentage: parseFloat(percentage.toFixed(2)),
              studentName: stats.studentName,
              rollNumber: stats.rollNumber,
            };
          }

          await summaryRef.set({
            month: monthKey,
            classSectionId: classSectionId,
            students: summaryData,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`Summary generated for ${schoolId}/${classSectionId}/${monthKey}`);
        }
      }

      console.log("Monthly summaries generation completed");
      return { success: true };

    } catch (error) {
      console.error("Error generating monthly summaries:", error);
      throw error;
    }
  });

/**
 * SEND LOW ATTENDANCE ALERTS
 * Runs daily at 8:00 PM
 * Sends notifications to parents if student attendance falls below threshold
 */
exports.sendLowAttendanceAlerts = functions
  .region("asia-south1")
  .pubsub.schedule("0 20 * * *") // 8:00 PM daily
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    try {
      const threshold = 75; // Alert if below 75%
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

      console.log(`Checking low attendance for month: ${monthKey}`);

      const schoolsSnapshot = await db.collection("schools").get();

      for (const schoolDoc of schoolsSnapshot.docs) {
        const schoolId = schoolDoc.id;

        // Get monthly summaries
        const summariesSnapshot = await db
          .collection("schools")
          .doc(schoolId)
          .collection("attendance_summary")
          .get();

        for (const classSectionDoc of summariesSnapshot.docs) {
          const classSectionId = classSectionDoc.id;

          const monthDoc = await db
            .collection("schools")
            .doc(schoolId)
            .collection("attendance_summary")
            .doc(classSectionId)
            .collection("months")
            .doc(monthKey)
            .get();

          if (!monthDoc.exists) continue;

          const monthData = monthDoc.data();
          const students = monthData.students || {};

          for (const [studentId, stats] of Object.entries(students)) {
            if (stats.percentage < threshold) {
              // Get parent FCM tokens
              const studentDoc = await db
                .collection("schools")
                .doc(schoolId)
                .collection("students")
                .doc(studentId)
                .get();

              if (!studentDoc.exists) continue;

              const parentId = studentDoc.data().parentId;
              if (!parentId) continue;

              const parentDoc = await db
                .collection("schools")
                .doc(schoolId)
                .collection("users")
                .doc(parentId)
                .get();

              if (!parentDoc.exists) continue;

              const fcmToken = parentDoc.data().fcmToken;
              if (!fcmToken) continue;

              // Send notification
              const message = {
                notification: {
                  title: "Low Attendance Alert",
                  body: `${stats.studentName}'s attendance is ${stats.percentage.toFixed(1)}% this month`,
                },
                data: {
                  type: "low_attendance",
                  studentId: studentId,
                  percentage: stats.percentage.toString(),
                },
                token: fcmToken,
              };

              try {
                await admin.messaging().send(message);
                console.log(`Alert sent to parent of ${stats.studentName}`);
              } catch (error) {
                console.error(`Failed to send notification to ${parentId}:`, error);
              }
            }
          }
        }
      }

      console.log("Low attendance alerts completed");
      return { success: true };

    } catch (error) {
      console.error("Error sending low attendance alerts:", error);
      throw error;
    }
  });

/**
 * NOTIFY PARENT WHEN STUDENT IS MARKED ABSENT
 * Real-time trigger when attendance is saved with absent status
 * Sends immediate notification to parent
 */
exports.notifyParentIfAbsent = functions
  .region("asia-south1")
  .firestore.document(
    "schools/{schoolId}/attendance/{classSectionId}/days/{date}"
  )
  .onWrite(async (change, context) => {
    try {
      // Exit if document was deleted
      if (!change.after.exists) return null;

      const { schoolId, classSectionId, date } = context.params;
      const afterData = change.after.data();
      const beforeData = change.before.exists ? change.before.data() : null;

      const afterStudents = afterData.students || {};
      const beforeStudents = beforeData?.students || {};

      console.log(`Checking absents for ${schoolId}/${classSectionId}/${date}`);

      // Check each student for newly marked absents
      for (const [studentId, studentInfo] of Object.entries(afterStudents)) {
        const currentStatus = studentInfo.status;
        const previousStatus = beforeStudents[studentId]?.status;

        // Only notify if newly marked absent (not if already was absent)
        if (currentStatus === "A" && previousStatus !== "A") {
          console.log(`Student ${studentId} newly marked absent`);

          // Get student details
          const studentDoc = await db
            .collection("schools")
            .doc(schoolId)
            .collection("students")
            .doc(studentId)
            .get();

          if (!studentDoc.exists) {
            console.log(`Student ${studentId} not found in database`);
            continue;
          }

          const studentData = studentDoc.data();
          const parentId = studentData.parentId;

          if (!parentId) {
            console.log(`No parent linked for student ${studentId}`);
            continue;
          }

          // Get parent FCM token
          const parentDoc = await db
            .collection("schools")
            .doc(schoolId)
            .collection("users")
            .doc(parentId)
            .get();

          if (!parentDoc.exists) {
            console.log(`Parent ${parentId} not found`);
            continue;
          }

          const fcmToken = parentDoc.data().fcmToken;

          if (!fcmToken) {
            console.log(`No FCM token for parent ${parentId}`);
            continue;
          }

          // Format date for display
          const dateObj = new Date(date);
          const formattedDate = dateObj.toLocaleDateString("en-IN", {
            day: "numeric",
            month: "short",
            year: "numeric",
          });

          // Send notification
          const message = {
            notification: {
              title: "Attendance Alert - Absent",
              body: `${studentInfo.studentName || "Your child"} was marked absent on ${formattedDate}`,
            },
            data: {
              type: "absent_notification",
              studentId: studentId,
              studentName: studentInfo.studentName || "Student",
              date: date,
              classSectionId: classSectionId,
            },
            token: fcmToken,
          };

          try {
            await admin.messaging().send(message);
            console.log(`Absent notification sent to parent of ${studentInfo.studentName}`);

            // Log notification in Firestore for tracking
            await db
              .collection("schools")
              .doc(schoolId)
              .collection("notifications_log")
              .add({
                type: "absent_notification",
                studentId: studentId,
                parentId: parentId,
                date: date,
                classSectionId: classSectionId,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "sent",
              });

          } catch (error) {
            console.error(`Failed to send notification to parent ${parentId}:`, error);

            // Log failed notification
            await db
              .collection("schools")
              .doc(schoolId)
              .collection("notifications_log")
              .add({
                type: "absent_notification",
                studentId: studentId,
                parentId: parentId,
                date: date,
                classSectionId: classSectionId,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "failed",
                error: error.message,
              });
          }
        }
      }

      return null;

    } catch (error) {
      console.error("Error in notifyParentIfAbsent:", error);
      return null;
    }
  });

/**
 * NOTIFY PARENT OF CONSECUTIVE ABSENTS
 * Checks for 3+ consecutive absents and sends alert
 * Triggered when attendance is marked
 */
exports.notifyConsecutiveAbsents = functions
  .region("asia-south1")
  .firestore.document(
    "schools/{schoolId}/attendance/{classSectionId}/days/{date}"
  )
  .onWrite(async (change, context) => {
    try {
      if (!change.after.exists) return null;

      const { schoolId, classSectionId, date } = context.params;
      const afterData = change.after.data();
      const students = afterData.students || {};

      console.log(`Checking consecutive absents for ${schoolId}/${classSectionId}/${date}`);

      // Get last 5 days of attendance
      const dateObj = new Date(date);
      const fiveDaysAgo = new Date(dateObj);
      fiveDaysAgo.setDate(dateObj.getDate() - 5);

      const recentDaysSnapshot = await db
        .collection("schools")
        .doc(schoolId)
        .collection("attendance")
        .doc(classSectionId)
        .collection("days")
        .where("meta.date", ">=", admin.firestore.Timestamp.fromDate(fiveDaysAgo))
        .where("meta.date", "<=", admin.firestore.Timestamp.fromDate(dateObj))
        .orderBy("meta.date", "desc")
        .limit(5)
        .get();

      // Track consecutive absents per student
      const studentAbsents = {};

      for (const dayDoc of recentDaysSnapshot.docs) {
        const dayData = dayDoc.data();
        const dayStudents = dayData.students || {};
        const isHoliday = dayData.meta?.isHoliday || false;

        if (isHoliday) continue; // Skip holidays

        for (const [studentId, studentInfo] of Object.entries(dayStudents)) {
          if (!studentAbsents[studentId]) {
            studentAbsents[studentId] = {
              consecutive: 0,
              broken: false,
              studentName: studentInfo.studentName,
              rollNumber: studentInfo.rollNumber,
            };
          }

          if (studentAbsents[studentId].broken) continue;

          if (studentInfo.status === "A") {
            studentAbsents[studentId].consecutive++;
          } else {
            studentAbsents[studentId].broken = true;
          }
        }
      }

      // Send alerts for students with 3+ consecutive absents
      for (const [studentId, absentInfo] of Object.entries(studentAbsents)) {
        if (absentInfo.consecutive >= 3 && !absentInfo.broken) {
          console.log(`Student ${studentId} has ${absentInfo.consecutive} consecutive absents`);

          // Check if we already sent an alert today
          const existingAlertSnapshot = await db
            .collection("schools")
            .doc(schoolId)
            .collection("notifications_log")
            .where("type", "==", "consecutive_absent_alert")
            .where("studentId", "==", studentId)
            .where("date", "==", date)
            .limit(1)
            .get();

          if (!existingAlertSnapshot.empty) {
            console.log(`Alert already sent for student ${studentId} today`);
            continue;
          }

          // Get parent info
          const studentDoc = await db
            .collection("schools")
            .doc(schoolId)
            .collection("students")
            .doc(studentId)
            .get();

          if (!studentDoc.exists) continue;

          const parentId = studentDoc.data().parentId;
          if (!parentId) continue;

          const parentDoc = await db
            .collection("schools")
            .doc(schoolId)
            .collection("users")
            .doc(parentId)
            .get();

          if (!parentDoc.exists) continue;

          const fcmToken = parentDoc.data().fcmToken;
          if (!fcmToken) continue;

          // Send urgent notification
          const message = {
            notification: {
              title: "⚠️ Attendance Alert - Consecutive Absents",
              body: `${absentInfo.studentName} has been absent for ${absentInfo.consecutive} consecutive days. Please contact the school.`,
            },
            data: {
              type: "consecutive_absent_alert",
              studentId: studentId,
              studentName: absentInfo.studentName,
              consecutiveDays: absentInfo.consecutive.toString(),
              date: date,
            },
            android: {
              priority: "high",
            },
            apns: {
              headers: {
                "apns-priority": "10",
              },
            },
            token: fcmToken,
          };

          try {
            await admin.messaging().send(message);
            console.log(`Consecutive absent alert sent for ${absentInfo.studentName}`);

            // Log alert
            await db
              .collection("schools")
              .doc(schoolId)
              .collection("notifications_log")
              .add({
                type: "consecutive_absent_alert",
                studentId: studentId,
                parentId: parentId,
                date: date,
                consecutiveDays: absentInfo.consecutive,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "sent",
              });

          } catch (error) {
            console.error(`Failed to send consecutive absent alert:`, error);
          }
        }
      }

      return null;

    } catch (error) {
      console.error("Error in notifyConsecutiveAbsents:", error);
      return null;
    }
  });

  // ======================================================
// SCHOOL MASTER DATA SYNC FUNCTION (GOOGLE SHEET)
// ======================================================

exports.syncSchoolData = functions
  .region("asia-south1")
  .https.onRequest(async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).send("Method Not Allowed");
      }

      const teachers = req.body.teachers || [];
      const students = req.body.students || [];
      const parents = req.body.parents || [];
      const teacherClassAssignments = req.body.teacherClassAssignments || [];

      const schoolRef = db.collection("school_001").doc("school_001");
      const countersRef = schoolRef.collection("counters").doc("system");
      const configRef = schoolRef.collection("config").doc("system");

      const configSnap = await configRef.get();
      const currentAcademicYear = configSnap.exists
        ? configSnap.data().currentAcademicYear
        : "2026";



     // ==========================
// PARENTS SYNC (SAFE MATCHING)
// ==========================
for (const parent of parents) {
  const fatherPhone = parent.fatherPhone ? parent.fatherPhone.trim() : "";
  const motherPhone = parent.motherPhone ? parent.motherPhone.trim() : "";
  const guardianPhone = parent.guardianPhone ? parent.guardianPhone.trim() : "";

  if (!fatherPhone && !motherPhone && !guardianPhone) continue;

  const parentCollection = schoolRef.collection("parents");

  let existingSnap = null;

  // Try matching by fatherPhone
  if (fatherPhone) {
    existingSnap = await parentCollection
      .where("fatherPhone", "==", fatherPhone)
      .limit(1)
      .get();
  }

  // If not found, try motherPhone
  if ((!existingSnap || existingSnap.empty) && motherPhone) {
    existingSnap = await parentCollection
      .where("motherPhone", "==", motherPhone)
      .limit(1)
      .get();
  }

  // If not found, try guardianPhone
  if ((!existingSnap || existingSnap.empty) && guardianPhone) {
    existingSnap = await parentCollection
      .where("guardianPhone", "==", guardianPhone)
      .limit(1)
      .get();
  }

  if (existingSnap && !existingSnap.empty) {
    const doc = existingSnap.docs[0];

    await doc.ref.update({
      fatherName: parent.fatherName || "",
      fatherPhone: fatherPhone,
      motherName: parent.motherName || "",
      motherPhone: motherPhone,
      guardianName: parent.guardianName || "",
      guardianPhone: guardianPhone,
      primaryContact: parent.primaryContact || "Father",
      address: parent.address || "",
      isActive: parent.isActive === "TRUE",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  } else {
    await db.runTransaction(async (t) => {
      const counterSnap = await t.get(countersRef);
      const parentCounter =
        (counterSnap.exists ? counterSnap.data().parentCounter : 0) + 1;

      const parentId = "P" + String(parentCounter).padStart(3, "0");

      t.set(parentCollection.doc(parentId), {
        parentId: parentId,
        fatherName: parent.fatherName || "",
        fatherPhone: fatherPhone,
        motherName: parent.motherName || "",
        motherPhone: motherPhone,
        guardianName: parent.guardianName || "",
        guardianPhone: guardianPhone,
        primaryContact: parent.primaryContact || "Father",
        address: parent.address || "",
        isActive: parent.isActive === "TRUE",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      t.set(
        countersRef,
        { parentCounter: parentCounter },
        { merge: true }
      );
    });
  }
}
     








      // ==========================
      // TEACHERS SYNC
      // ==========================
      for (const teacher of teachers) {
        const email = teacher.email ? teacher.email.trim() : "";
        if (!email) continue;

        const teacherCollection = schoolRef.collection("teachers");

        const existingSnap = await teacherCollection
          .where("email", "==", email)
          .limit(1)
          .get();

        if (!existingSnap.empty) {
          const doc = existingSnap.docs[0];
          await doc.ref.update({
            name: teacher.name || "",
            phone: teacher.phone || "",
            isActive: teacher.isActive === "TRUE",
          });
        } else {
          await db.runTransaction(async (t) => {
            const counterSnap = await t.get(countersRef);
            const teacherCounter =
              (counterSnap.exists ? counterSnap.data().teacherCounter : 0) + 1;

            const teacherId = "T" + String(teacherCounter).padStart(3, "0");

            t.set(teacherCollection.doc(teacherId), {
              teacherId: teacherId,
              name: teacher.name || "",
              email: email,
              phone: teacher.phone || "",
              canTakeAttendance: false,
              isActive: teacher.isActive === "TRUE",
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            t.set(
              countersRef,
              { teacherCounter: teacherCounter },
              { merge: true }
            );
          });
        }
      }

      // ==========================
      // STUDENTS SYNC
      // ==========================
     // STUDENT SYNC LOGIC
// - Generates sequential studentId (S001...)
// - Links student to parent using parentPhone
// - Converts isActive safely from Google Sheet boolean/string
// - Prevents duplicate admissionNumber
     // ==========================
// STUDENTS SYNC (PRO VERSION WITH PARENT LINKING)
// ==========================
for (const student of students) {

  const admissionNumber = student.admissionNumber
    ? String(student.admissionNumber).trim()
    : "";

  if (!admissionNumber) continue;

  const parentPhone = student.parentPhone
    ? String(student.parentPhone).trim()
    : "";

  const studentCollection = schoolRef.collection("students");
  const parentCollection = schoolRef.collection("parents");

  // 🔎 FIND PARENT USING PHONE
  let parentId = null;

  if (parentPhone) {

    const fatherMatch = await parentCollection
      .where("fatherPhone", "==", parentPhone)
      .limit(1)
      .get();

    if (!fatherMatch.empty) {
      parentId = fatherMatch.docs[0].id;
    }

    if (!parentId) {
      const motherMatch = await parentCollection
        .where("motherPhone", "==", parentPhone)
        .limit(1)
        .get();

      if (!motherMatch.empty) {
        parentId = motherMatch.docs[0].id;
      }
    }

    if (!parentId) {
      const guardianMatch = await parentCollection
        .where("guardianPhone", "==", parentPhone)
        .limit(1)
        .get();

      if (!guardianMatch.empty) {
        parentId = guardianMatch.docs[0].id;
      }
    }
  }

  const existingSnap = await studentCollection
    .where("admissionNumber", "==", admissionNumber)
    .limit(1)
    .get();

  if (!existingSnap.empty) {

    const doc = existingSnap.docs[0];

    const updateData = {
      name: student.name || "",
      gender: student.gender || "",
      class: student.class || "",
      section: student.section || "",
      admissionDate: student.admissionDate || "",
      academicYear: currentAcademicYear,
      parentId: parentId || null,
      isActive: String(student.isActive).toLowerCase() === "true",
    };

    if (student.bloodGroup) {
      updateData.bloodGroup = student.bloodGroup;
    }

    if (student.boardingType) {
      updateData.boardingType = student.boardingType;
    }

    await doc.ref.update(updateData);

  } else {

    await db.runTransaction(async (t) => {

      const counterSnap = await t.get(countersRef);

      const studentCounter =
        (counterSnap.exists ? counterSnap.data().studentCounter || 0 : 0) + 1;

      const studentId = "S" + String(studentCounter).padStart(3, "0");

     t.set(studentCollection.doc(studentId), {
  studentId: studentId,
  admissionNumber: admissionNumber,
  name: student.name || "",
  gender: student.gender || "",
  bloodGroup: student.bloodGroup || null,
  class: student.class || "",
  section: student.section || "",
  boardingType: student.boardingType || null,
  admissionDate: student.admissionDate || "",
  academicYear: currentAcademicYear,
  isActive: String(student.isActive).toLowerCase() === "true",
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
});

      t.set(
        countersRef,
        { studentCounter: studentCounter },
        { merge: true }
      );
    });
  }
}
      return res.status(200).json({ success: true });

    } catch (error) {
      console.error("Sync Error:", error);
      return res.status(500).json({ error: error.message });
    }
  });