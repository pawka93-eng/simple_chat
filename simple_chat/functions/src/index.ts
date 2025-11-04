import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

admin.initializeApp();

export const onNewMessage = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const msg = snap.data() as {
      text?: string;
      senderUid: string;
      senderEmail?: string;
    };

    const chatId = event.params.chatId as string;
    const chatRef = admin.firestore().collection('chats').doc(chatId);
    const chatDoc = await chatRef.get();
    if (!chatDoc.exists) return;

    const members = chatDoc.get('members') as string[];
    if (!Array.isArray(members) || members.length !== 2) return;

    const recipients = members.filter((m) => m !== msg.senderUid);

    // pobierz tokeny FCM odbiorców
    const usersSnap = await admin
      .firestore()
      .collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', recipients)
      .get();

    const tokens: string[] = [];
    usersSnap.forEach((u) => {
      const t = u.get('fcmTokens') as string[] | undefined;
      if (Array.isArray(t)) tokens.push(...t);
    });

    if (!tokens.length) return;

    const title = msg.senderEmail ?? 'Nowa wiadomość';
    const body =
      msg.text && msg.text.trim().length > 0
        ? msg.text.trim()
        : 'Wysłano wiadomość';

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      android: {
        notification: {
          channelId: 'chat_messages',
          priority: 'high',
          defaultSound: true
        }
      },
      data: { chatId, senderUid: msg.senderUid }
    });
  }
);
