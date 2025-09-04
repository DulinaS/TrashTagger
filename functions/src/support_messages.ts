// functions/src/support_messages.ts
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';

// Configure email transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: functions.config().email?.user || 'your-admin@gmail.com',
    pass: functions.config().email?.password || 'your-app-password',
  },
});

// ================================
// SUPPORT MESSAGE CREATION
// ================================

export const submitSupportMessage = functions.https.onCall(
  async (data, context) => {
    // Authentication required
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to submit support messages'
      );
    }

    const {
      subject,
      message,
      category,
      priority = 'medium',
      attachments = [],
    } = data;

    // Validation
    if (!subject || !message || !category) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Subject, message, and category are required'
      );
    }

    if (message.length > 2000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message must be less than 2000 characters'
      );
    }

    try {
      const userId = context.auth.uid;

      // Get user data
      const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(userId)
        .get();

      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'User profile not found'
        );
      }

      const userData = userDoc.data()!;

      // Create support message document
      const supportMessage = {
        userId,
        userName: userData.name || 'Anonymous',
        userEmail: userData.email || 'no-email@example.com',
        subject: subject.trim(),
        message: message.trim(),
        category,
        priority,
        status: 'open',
        attachments,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        adminResponse: null,
        adminId: null,
        respondedAt: null,
      };

      // Save to Firestore
      const docRef = await admin
        .firestore()
        .collection('supportMessages')
        .add(supportMessage);

      console.log(`Support message created: ${docRef.id}`);

      return {
        success: true,
        messageId: docRef.id,
        message: 'Support message submitted successfully',
      };
    } catch (error) {
      console.error('Error creating support message:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to submit support message'
      );
    }
  }
);

// ================================
// EMAIL NOTIFICATION TO ADMIN
// ================================

export const notifyAdminNewSupportMessage = functions.firestore
  .document('supportMessages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const messageId = context.params.messageId;

    try {
      // Check if email is configured
      const emailConfig = functions.config().email;
      if (!emailConfig || !emailConfig.user || !emailConfig.admin) {
        console.log('Email not configured, skipping notification');
        return { success: false, reason: 'Email not configured' };
      }

      // Priority emoji
      const priorityEmoji = {
        low: '🔵',
        medium: '🟡',
        high: '🔴',
      };

      // Category emoji
      const categoryEmoji = {
        bug: '🐛',
        feature: '💡',
        general: '💬',
        account: '👤',
        technical: '⚙️',
      };

      const mailOptions = {
        from: emailConfig.user,
        to: emailConfig.admin,
        subject: `[TrashTagger Support] ${messageData.subject}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: #2E7D32; color: white; padding: 20px; text-align: center;">
              <h2>🗑️ TrashTagger Support - New Message</h2>
            </div>
            
            <div style="padding: 20px; background: #f5f5f5;">
              <table style="width: 100%; border-collapse: collapse;">
                <tr>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>From:</strong></td>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;">${
                    messageData.userName
                  } (${messageData.userEmail})</td>
                </tr>
                <tr>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Category:</strong></td>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;">${
                    messageData.category
                  }</td>
                </tr>
                <tr>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Priority:</strong></td>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;">${messageData.priority.toUpperCase()}</td>
                </tr>
                <tr>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Subject:</strong></td>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;">${
                    messageData.subject
                  }</td>
                </tr>
                <tr>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Message ID:</strong></td>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;">${messageId}</td>
                </tr>
                <tr>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Submitted:</strong></td>
                  <td style="padding: 10px; border-bottom: 1px solid #ddd;">${new Date().toLocaleString()}</td>
                </tr>
              </table>
            </div>

            <div style="padding: 20px;">
              <h3>Message:</h3>
              <div style="padding: 15px; background: white; border: 1px solid #ddd; border-radius: 5px; white-space: pre-wrap;">${
                messageData.message
              }</div>
            </div>

            ${
              messageData.attachments && messageData.attachments.length > 0
                ? `
            <div style="padding: 20px;">
              <h3>Attachments:</h3>
              <ul>
                ${messageData.attachments
                  .map(
                    (url: string, index: number) => `
                  <li><a href="${url}">Attachment ${index + 1}</a></li>
                `
                  )
                  .join('')}
              </ul>
            </div>
            `
                : ''
            }

            <div style="padding: 20px; text-align: center; background: #f9f9f9;">
              <a href="${
                emailConfig.admin_panel_url || 'https://admin.trashtagger.com'
              }/support/${messageId}" 
                 style="display: inline-block; padding: 12px 24px; background: #2E7D32; color: white; text-decoration: none; border-radius: 5px;">
                View in Admin Panel
              </a>
            </div>
          </div>
        `,
      };

      await transporter.sendMail(mailOptions);
      console.log(`Admin notified about support message: ${messageId}`);

      // Update message with notification status
      await snap.ref.update({
        adminNotified: true,
        adminNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    } catch (error) {
      console.error('Error sending admin notification:', error);

      // Update message with notification failure
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      await snap.ref.update({
        adminNotified: false,
        adminNotificationError: errorMessage,
      });

      return { success: false, error: String(error) };
    }
  });

// ================================
// USER NOTIFICATION FOR ADMIN RESPONSE
// ================================

export const notifyUserSupportResponse = functions.firestore
  .document('supportMessages/{messageId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const messageId = context.params.messageId;

    // Check if admin response was added
    if (!beforeData.adminResponse && afterData.adminResponse) {
      try {
        // Create in-app notification
        await admin
          .firestore()
          .collection('notifications')
          .add({
            userId: afterData.userId,
            type: 'support_response',
            title: 'Support Team Response',
            body: `We've responded to your message: "${afterData.subject}"`,
            data: {
              messageId,
              action: 'view_support_response',
              category: afterData.category,
            },
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        // Optional: Send email if configured
        const emailConfig = functions.config().email;
        if (
          emailConfig &&
          emailConfig.user &&
          afterData.userEmail !== 'no-email@example.com'
        ) {
          const mailOptions = {
            from: emailConfig.user,
            to: afterData.userEmail,
            subject: '[TrashTagger] Response to your support message',
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <div style="background: #2E7D32; color: white; padding: 20px; text-align: center;">
                  <h2>🗑️ TrashTagger Support Response</h2>
                </div>
                
                <div style="padding: 20px;">
                  <p>Hello ${afterData.userName},</p>
                  <p>We've responded to your support message about: <strong>${afterData.subject}</strong></p>
                  
                  <div style="padding: 15px; background: #f0f8ff; border: 1px solid #ddd; border-radius: 5px; margin: 20px 0;">
                    <h3>Our Response:</h3>
                    <div style="white-space: pre-wrap;">${afterData.adminResponse}</div>
                  </div>
                  
                  <p>If you have any follow-up questions, please feel free to submit another support message through the app.</p>
                  <p>Thank you for using TrashTagger and helping make our communities cleaner!</p>
                  
                  <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
                    <p>This is an automated response. Please do not reply to this email directly.</p>
                  </div>
                </div>
              </div>
            `,
          };

          await transporter.sendMail(mailOptions);
          console.log(
            `User notified via email about admin response: ${messageId}`
          );
        }

        console.log(`User notified about admin response: ${messageId}`);
        return { success: true };
      } catch (error) {
        console.error('Error sending user notification:', error);
        return { success: false, error: String(error) };
      }
    }

    return null;
  });

// ================================
// GET USER'S SUPPORT MESSAGES
// ================================

export const getUserSupportMessages = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    try {
      const userId = context.auth.uid;
      const { limit = 10, status = 'all' } = data;

      let query = admin
        .firestore()
        .collection('supportMessages')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(limit);

      if (status !== 'all') {
        query = query.where('status', '==', status);
      }

      const snapshot = await query.get();
      const messages = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      return {
        success: true,
        messages,
        count: messages.length,
      };
    } catch (error) {
      console.error('Error getting user support messages:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to get support messages'
      );
    }
  }
);
