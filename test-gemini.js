(async () => {
  const key = process.env.GEMINI_API_KEY;
  if (!key) {
    console.error('GEMINI_API_KEY not set');
    process.exit(1);
  }

  // Choose a model that the key supports (non‑Pro)
  const model = 'gemini-2.0-flash';
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
