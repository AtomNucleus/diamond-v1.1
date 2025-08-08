require('dotenv').config();

const express = require('express');

const app = express();
app.set('trust proxy', 1);
app.use(express.json());

// In-memory storage for user access tokens
const userStore = {};

// Health‑check
app.get('/health', (req, res) => res.send('OK'));

// Mock Teller OAuth URL (for testing)
app.post('/teller/auth_url', async (req, res) => {
  try {
    // Mock OAuth URL that redirects to our own mock OAuth page
    const authURL = `${req.protocol}://${req.get('host')}/mock-oauth`;
    res.json({ authURL });
  } catch (err) {
    console.error('🔴 Mock Teller API error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Mock OAuth page
app.get('/mock-oauth', (req, res) => {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
        <title>Mock Teller OAuth</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
            .container { max-width: 400px; margin: 0 auto; }
            .button { background: #007AFF; color: white; padding: 15px 30px; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; margin: 10px; }
            .button:hover { background: #0056CC; }
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Mock Teller Bank Connection</h2>
            <p>This is a mock OAuth page for testing purposes.</p>
            <p>Click the button below to simulate a successful bank connection:</p>
            <button class="button" onclick="connectBank()">Connect Bank Account</button>
            <br><br>
            <button class="button" onclick="cancel()" style="background: #FF3B30;">Cancel</button>
        </div>
        <script>
            function connectBank() {
                // Simulate successful OAuth redirect
                const mockCode = 'mock_auth_code_' + Date.now();
                const redirectUri = 'diamondapp://teller-oauth?code=' + mockCode;
                window.location.href = redirectUri;
            }
            function cancel() {
                const redirectUri = 'diamondapp://teller-oauth?error=cancelled';
                window.location.href = redirectUri;
            }
        </script>
    </body>
    </html>
  `;
  res.send(html);
});

// Mock exchange authorization code for access token
app.post('/teller/exchange_code', async (req, res) => {
  const { code } = req.body;
  try {
    // Mock successful token exchange
    const userId = 'diamond-user-123';
    userStore[userId] = { access_token: 'mock_access_token_123', item_id: 'mock_institution_123' };
    res.json({ message: 'Access token exchanged successfully.' });
  } catch (err) {
    console.error('🔴 Mock Teller API error in exchange:', err);
    res.status(500).json({ error: err.message });
  }
});

// Mock get user accounts
app.get('/teller/accounts', async (req, res) => {
  const userId = req.query.userId || 'diamond-user-123';
  const stored = userStore[userId];
  if (!stored?.access_token) {
    return res.status(400).json({ error: 'no access_token for user' });
  }
  try {
    // Mock accounts data
    const accounts = [
      { id: 'acc_1', name: 'Checking Account', type: 'checking', balance: 2500.00 },
      { id: 'acc_2', name: 'Savings Account', type: 'savings', balance: 15000.00 }
    ];
    res.json(accounts);
  } catch (err) {
    console.error('🔴 Mock Teller API error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Mock get transactions
app.get('/teller/transactions', async (req, res) => {
  const userId = req.query.userId || 'diamond-user-123';
  const stored = userStore[userId];
  if (!stored?.access_token) {
    return res.status(400).json({ error: 'no access_token for user' });
  }
  try {
    // Mock transactions data
    const transactions = {
      items: [
        { id: 'txn_1', amount: '45.67', date: '2024-06-27', description: 'Coffee Shop' },
        { id: 'txn_2', amount: '120.50', date: '2024-06-26', description: 'Grocery Store' },
        { id: 'txn_3', amount: '89.99', date: '2024-06-25', description: 'Online Purchase' },
        { id: 'txn_4', amount: '25.00', date: '2024-06-24', description: 'Gas Station' },
        { id: 'txn_5', amount: '150.00', date: '2024-06-23', description: 'Restaurant' }
      ]
    };
    res.json(transactions);
  } catch (err) {
    console.error('🔴 Mock Teller API error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Endpoint for daily/weekly/monthly spend summary
app.get('/spend_summary', async (req, res) => {
  // For testing purposes, always return mock data regardless of access token
  try {
    // Mock spend summary data
    const now = new Date();
    const fmt = d => d.toISOString().slice(0,10);
    const endDate = fmt(now);
    const startDay = fmt(new Date(now.getFullYear(), now.getMonth(), now.getDate()));
    const startMon = fmt(new Date(now.getFullYear(), now.getMonth(), 1));
    const startWk = fmt(new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay()));
    
    // Mock transaction amounts
    const daily = 45.67;
    const weekly = 330.16;
    const monthly = 1250.50;
    
    res.json({
      daily: { date: startDay, total: daily },
      weekly: { start: startWk, end: endDate, total: weekly },
      monthly: { year: now.getFullYear(), month: now.getMonth()+1, total: monthly }
    });
  } catch (err) {
    console.error('Spend summary error', err);
    res.status(500).json({ error: 'spend_summary_failed' });
  }
});

// Handle Teller webhooks
app.post('/teller/webhook', (req, res) => {
  // Implement webhook handling logic here
  console.log('Received Teller webhook:', req.body);
  res.sendStatus(200);
});

// Define PORT and start server
const PORT = process.env.PORT || 5001;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🟢 Server listening on port ${PORT}`);
  console.log(`📡 Mock Teller API endpoints available at http://localhost:${PORT}`);
});