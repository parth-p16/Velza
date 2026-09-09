const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Triggered whenever a message is queued into the /notifications collection
 */
exports.sendQueuedNotification = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const { senderId, senderName, receiverId, chatId, title, body, type } = data;

    if (!receiverId || receiverId === senderId) {
      console.log(`[FCM] Skipped: receiver is missing or self-message (${receiverId})`);
      return null;
    }

    try {
      const userDoc = await db.collection("users").doc(receiverId).get();
      if (!userDoc.exists) {
        console.log(`[FCM] Target user ${receiverId} not found in Firestore`);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData ? userData.fcmToken : null;

      if (!fcmToken) {
        console.log(`[FCM] Target user ${receiverId} has no fcmToken registered`);
        return null;
      }

      const messagePayload = {
        token: fcmToken,
        notification: {
          title: title || senderName || "Velza Message",
          body: body || "You received a new message",
        },
        data: {
          chatId: String(chatId || ""),
          senderId: String(senderId || ""),
          senderName: String(senderName || ""),
          type: String(type || "text"),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "velza_messages_channel",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(messagePayload);
      console.log(`[FCM SUCCESS] Message sent to ${receiverId} (${response})`);

      return snap.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response,
      });
    } catch (error) {
      console.error(`[FCM ERROR] Delivery failed for ${receiverId}:`, error);
      return snap.ref.update({
        status: "failed",
        error: error.message,
      });
    }
  });

/**
 * Triggered whenever a new message document is created in any chat
 */
exports.onChatMessageCreated = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message) return null;

    const { chatId } = context.params;
    const { senderId, senderName, text, type, fileName } = message;

    try {
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (!chatDoc.exists) return null;

      const chatData = chatDoc.data();
      const memberIds = chatData.memberIds || [];

      // Preview text depending on message type
      let previewText = text || "New message";
      if (type === "image") previewText = "📷 Photo";
      else if (type === "video") previewText = "🎥 Video";
      else if (type === "audio") previewText = "🎤 Voice message";
      else if (type === "sticker") previewText = "🏷️ Sticker";
      else if (type === "document") previewText = fileName ? `📄 ${fileName}` : "📄 Document";

      // Send to all other members
      const sendPromises = memberIds
        .filter((uid) => uid !== senderId)
        .map(async (recipientUid) => {
          const recipientSnap = await db.collection("users").doc(recipientUid).get();
          if (!recipientSnap.exists) return null;

          const recipientData = recipientSnap.data();
          const token = recipientData ? recipientData.fcmToken : null;
          if (!token) return null;

          const payload = {
            token,
            notification: {
              title: senderName || "New Message",
              body: previewText,
            },
            data: {
              chatId: String(chatId),
              senderId: String(senderId),
              senderName: String(senderName || ""),
              type: String(type || "text"),
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
              priority: "high",
              notification: {
                channelId: "velza_messages_channel",
                priority: "high",
                defaultSound: true,
                defaultVibrateTimings: true,
              },
            },
          };

          try {
            return await admin.messaging().send(payload);
          } catch (err) {
            console.error(`[FCM Message ERROR] failed for ${recipientUid}:`, err);
            return null;
          }
        });

      await Promise.all(sendPromises);
      return null;
    } catch (err) {
      console.error("[FCM Chat ERROR]", err);
      return null;
    }
  });
