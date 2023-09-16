import Mailjet from "node-mailjet";

if (typeof process.env.MJ_API_KEY !== "string") {
  console.log("MJ_API_KEY is missing");
  process.exit(1);
}

if (typeof process.env.MJ_API_SECRET !== "string") {
  console.log("MJ_API_SECRET is missing");
  process.exit(1);
}

const mailjet = Mailjet.apiConnect(
  process.env.MJ_API_KEY,
  process.env.MJ_API_SECRET
);

export async function handler(event, context) {
  const { Records } = event;

  const tasks = Records.map(record => {
    const { Sns: { Subject, Message } } = record;

    switch (Subject) {
      case "gg.syren.marketing.MailingListSubscribed-v1/json": {
        const { email } = JSON.parse(Message);
        return mailjet
          .post('contact', { version: 'v3' })
          .request({ Email: email });
      }

      default: {
        console.log(`unknown event type "${Subject}", ignoring`);
        return;
      }
    }
  });

  await Promise.all(tasks);
}
