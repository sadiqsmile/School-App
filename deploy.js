const { execSync } = require('child_process');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('\n🚀 Firebase Deployment Script\n');
console.log('This script will deploy your Flutter web app to Firebase hosting.\n');

rl.question('Have you already logged into Firebase? (yes/no): ', (answer) => {
  if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
    console.log('\n✅ Proceeding with deployment...\n');
    try {
      console.log('Running: firebase deploy --only hosting\n');
      execSync('firebase deploy --only hosting', { stdio: 'inherit' });
      console.log('\n✅ Deployment completed successfully!\n');
    } catch (error) {
      console.error('\n❌ Deployment failed. Please check the error above and try again.\n');
      process.exit(1);
    }
  } else {
    console.log('\n📋 Please run the following command to login:\n');
    console.log('   firebase login\n');
    console.log('Then run this script again.\n');
  }
  rl.close();
});
