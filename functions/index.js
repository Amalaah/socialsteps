const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configure the email transporter
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "your-email@gmail.com", // Should be configured via environment variables in production
    pass: "your-app-password",
  },
});

/**
 * Scheduled function to send weekly progress reports every Tuesday at 11:45 PM (Asia/Kolkata).
 */
exports.scheduledWeeklyReport = onSchedule({
  schedule: "40 23 * * 2",
  timeZone: "Asia/Kolkata",
  memory: "256MiB",
}, async (event) => {
  try {
    await sendReports();
  } catch (error) {
    console.error("Error generating weekly reports:", error);
  }
});

/**
 * Manual trigger for testing the weekly report.
 */
exports.triggerWeeklyReportManual = onCall({
  memory: "256MiB",
}, async (request) => {
  // Check for admin/parent authentication if needed
  // For now, it runs the same logic as the scheduled one
  try {
    await sendReports();
    return { success: true, message: "Reports sent successfully" };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

async function sendReports() {
  const db = admin.firestore();
  const parentsSnapshot = await db.collection("parents").get();
    
  for (const parentDoc of parentsSnapshot.docs) {
    const parentData = parentDoc.data();
    const parentEmail = parentData.email;
    const parentId = parentDoc.id;

    if (!parentEmail) continue;

    const childrenSnapshot = await db.collection("parents").doc(parentId).collection("children").get();
    if (childrenSnapshot.empty) continue;

    let reportHtml = `<h2>Weekly Progress Report – SocialSteps</h2>`;
    for (const childDoc of childrenSnapshot.docs) {
      const child = childDoc.data();
      const name = child.name || "Your child";
      const accuracy = calculateOverallAccuracy(child);
      const timeSpent = calculateTotalTime(child);
      const completed = calculateModulesCompleted(child);

      reportHtml += `
        <div style="margin-bottom: 20px; border-bottom: 1px solid #ccc; padding-bottom: 10px;">
          <h3>Progress for ${name}</h3>
          <p><strong>Accuracy:</strong> ${(accuracy * 100).toFixed(1)}%</p>
          <p><strong>Total Time Spent:</strong> ${Math.floor(timeSpent / 60)} minutes</p>
          <p><strong>Modules Completed:</strong> ${completed}</p>
          <h4>Strengths:</h4>
          <ul>${getStrengths(child)}</ul>
          <h4>Areas to Improve:</h4>
          <ul>${getAreasToImprove(child)}</ul>
        </div>
      `;
    }

    await transporter.sendMail({
      from: '"SocialSteps Team" <no-reply@socialsteps.com>',
      to: parentEmail,
      subject: "Weekly Progress Report – SocialSteps",
      html: reportHtml,
    });
    console.log(`Sent weekly report to ${parentEmail}`);
  }
}

function calculateOverallAccuracy(data) {
  const modules = ["emotionAccuracy", "focusAccuracy", "puzzleAccuracy", "colorAccuracy", "socialAccuracy"];
  let sum = 0, count = 0;
  modules.forEach(m => {
    if (data[m] > 0) {
      sum += data[m];
      count++;
    }
  });
  return count > 0 ? sum / count : 0;
}

function calculateTotalTime(data) {
  const times = ["emotionTime", "focusTime", "puzzleTime", "colorTime", "socialTime"];
  return times.reduce((acc, t) => acc + (data[t] || 0), 0);
}

function calculateModulesCompleted(data) {
  const progress = ["emotionProgress", "focusProgress", "puzzleProgress", "colorProgress", "socialProgress"];
  return progress.filter(p => data[p] === 1.0).length;
}

function getStrengths(child) {
  let strengths = [];
  if (child.emotionAccuracy > 0.8) strengths.push("Strong emotion recognition skills.");
  if (child.focusAccuracy > 0.8) strengths.push("Excellent focus and attention span.");
  if (child.puzzleAccuracy > 0.8) strengths.push("Strong cognitive matching abilities.");
  if (child.streak > 5) strengths.push(`Consistent participation with a ${child.streak}-day streak.`);
  
  return strengths.length > 0 ? strengths.map(s => `<li>${s}</li>`).join("") : "<li>Continuing to build foundational skills.</li>";
}

function getAreasToImprove(child) {
  let improvements = [];
  if (child.emotionAccuracy > 0 && child.emotionAccuracy < 0.5) improvements.push("Practice identifying complex emotions.");
  if (child.focusAccuracy > 0 && child.focusAccuracy < 0.5) improvements.push("Work on sustaining attention in busier environments.");
  if (calculateTotalTime(child) < 300) improvements.push("Consider increasing weekly practice time.");
  
  return improvements.length > 0 ? improvements.map(i => `<li>${i}</li>`).join("") : "<li>Keep up the great work! No specific areas of concern this week.</li>";
}
