# 📥 CSV Import Templates for Modern Setup Wizard

This guide provides CSV templates for the Modern Admin Setup Wizard.

---

## 1️⃣ Classes & Sections CSV Template

### Format
```csv
classId,className,classOrder,sectionId,sectionName,sectionOrder
```

### Example
```csv
classId,className,classOrder,sectionId,sectionName,sectionOrder
class1,Class 1,1,A,Section A,1
class1,Class 1,1,B,Section B,2
class2,Class 2,2,A,Section A,1
class2,Class 2,2,B,Section B,2
class3,Class 3,3,A,Section A,1
```

### Field Descriptions
- **classId**: Unique identifier for the class (e.g., class1, class2)
- **className**: Display name for the class (e.g., Class 1, Class 2)
- **classOrder**: Sort order number for displaying classes (1, 2, 3...)
- **sectionId**: Unique identifier for the section (e.g., A, B, C)
- **sectionName**: Display name for the section (e.g., Section A)
- **sectionOrder**: Sort order number for displaying sections (1, 2, 3...)

---

## 2️⃣ Students CSV Template

### Format
```csv
admissionNo,studentName,classId,sectionId,rollNo,parentName,parentMobile
```

### Example
```csv
admissionNo,studentName,classId,sectionId,rollNo,parentName,parentMobile
2024001,John Doe,class1,A,1,Mr. Doe,9876543210
2024002,Jane Smith,class1,A,2,Mrs. Smith,9876543211
2024003,Bob Johnson,class1,B,1,Mr. Johnson,9876543212
```

### Field Descriptions
- **admissionNo**: Unique admission number for the student
- **studentName**: Full name of the student
- **classId**: Class ID from Classes CSV (must match)
- **sectionId**: Section ID from Classes CSV (must match)
- **rollNo**: Roll number within the class-section
- **parentName**: Parent/guardian's name
- **parentMobile**: Parent's mobile number (10 digits)

---

## 3️⃣ Parents CSV Template

### Format
```csv
phone,displayName,studentAdmissionNos
```

### Example
```csv
phone,displayName,studentAdmissionNos
9876543210,Mr. Doe,2024001
9876543211,Mrs. Smith,2024002;2024003
9876543212,Mr. Johnson,2024004
```

### Field Descriptions
- **phone**: 10-digit mobile number (becomes login ID)
- **displayName**: Parent's full name
- **studentAdmissionNos**: Comma or semicolon-separated admission numbers of their children

**Note**: Default password = last 4 digits of phone number

---

## 4️⃣ Teacher Assignments CSV Template

### Format
```csv
teacherUid,teacherName,classId,sectionId
```

### Example
```csv
teacherUid,teacherName,classId,sectionId
teacher001,Mr. Smith,class1,A
teacher001,Mr. Smith,class1,B
teacher002,Mrs. Jones,class2,A
```

### Field Descriptions
- **teacherUid**: Firebase Auth UID of the teacher (must be created first)
- **teacherName**: Teacher's display name
- **classId**: Class ID to assign
- **sectionId**: Section ID to assign

**Note**: One teacher can have multiple class-section assignments (one row per assignment)

---

## 🎯 How to Use

### In the Modern Setup Wizard:

1. **Step 1**: Create or select an Academic Year
2. **Step 2**: Choose "Import from CSV/Excel"
3. **Step 3**: Upload CSV files:
   - Import Classes & Sections first
   - Then import Students
   - Optionally import Parents
   - Finally import Teacher Assignments
4. **Step 4**: Preview and confirm all data
5. **Step 5**: Complete setup!

### Tips for CSV Files:

✅ **Use UTF-8 encoding**  
✅ **First row must be the header** (column names)  
✅ **No empty rows** between data  
✅ **Trim spaces** from values  
✅ **Test with small file first** (5-10 rows)  

❌ **Don't use special characters** in IDs (use letters, numbers, underscores)  
❌ **Don't skip required fields**  
❌ **Don't use Excel formulas** - export as CSV  

---

## 📱 Creating CSV Files

### From Excel:
1. Prepare data in Excel
2. File → Save As → Choose "CSV (Comma delimited)"
3. Upload to wizard

### From Google Sheets:
1. Prepare data in Google Sheets
2. File → Download → Comma Separated Values (.csv)
3. Upload to wizard

### Copy-Paste Method:
1. Select and copy data from Google Sheets/Excel
2. Paste into text editor (Notepad)
3. Save with .csv extension
4. Upload to wizard

---

## 🆘 Common Errors

| Error | Solution |
|-------|----------|
| "Missing required columns" | Check header row has exact column names (case-insensitive) |
| "Invalid classOrder" | Use numbers only (1, 2, 3...) |
| "classId is required" | Every row must have a classId |
| "Parse error" | Check for special characters, extra commas, or malformed rows |

---

## 💡 Pro Tips

1. **Import in Order**: Classes → Students → Parents → Assignments
2. **Start Small**: Test with 5 rows first, then import full data
3. **Backup**: Keep original Excel/Sheets file as backup
4. **Validate**: Use Step 4 Preview to check before importing
5. **Incremental**: You can import more data later using individual CSV import screens

---

## 🎓 Example Complete Setup

### 1. classes_sections.csv
```csv
classId,className,classOrder,sectionId,sectionName,sectionOrder
class1,Class 1,1,A,Section A,1
class1,Class 1,1,B,Section B,2
```

### 2. students.csv
```csv
admissionNo,studentName,classId,sectionId,rollNo,parentName,parentMobile
2024001,Alice Brown,class1,A,1,Mr. Brown,9876543210
2024002,Charlie Davis,class1,B,1,Mrs. Davis,9876543211
```

### 3. parents.csv
```csv
phone,displayName,studentAdmissionNos
9876543210,Mr. Brown,2024001
9876543211,Mrs. Davis,2024002
```

### 4. teacher_assignments.csv
```csv
teacherUid,teacherName,classId,sectionId
teacher001,Mr. Smith,class1,A
teacher001,Mr. Smith,class1,B
```

---

**Ready to import?** Open the Modern Setup Wizard and follow the steps! 🚀
