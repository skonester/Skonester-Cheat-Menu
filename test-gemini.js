(async () => {
  const key = process.env.GEMINI_API_KEY;
  if (!key) {
    console.error('GEMINI_API_KEY not set');
    process.exit(1);
  }

  // Use the highest‑tier flash model we have access to (2.5 Flash)
  const model = 'gemini-2.5-flash';
  const url = `https://generativelanguage.googleapis.com/v1/models/${model}:generateContent?key=${key}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: 'Explain how AI works in a few words' }] }]
    })
  });

  const data = await response.json();
  console.log(JSON.stringify(data, null, 2));
})();
