const express = require('express');
const axios = require('axios');
const { wrapper } = require('axios-cookiejar-support');
const { CookieJar } = require('tough-cookie');

const app = express();
const port = 3000;

// Replace with your Superset credentials and details
const SUPERSET_URL = 'http://192.168.178.10:8088';
const SUPERSET_USERNAME = 'admin';
const SUPERSET_PASSWORD = 'admin';
const DASHBOARD_ID = '12'; // Replace with your dashboard ID

// Create an axios instance with a cookie jar to automatically handle cookies
const jar = new CookieJar();
const client = wrapper(axios.create({ jar }));

app.use(express.static('public'));

app.get('/guest-token', async (req, res) => {
  try {
    // 1. Login to get the access_token and session cookie (handled by the jar)
    const loginResponse = await client.post(`${SUPERSET_URL}/api/v1/security/login`, {
      username: SUPERSET_USERNAME,
      password: SUPERSET_PASSWORD,
      provider: 'db',
    });
    const { access_token } = loginResponse.data;

    // 2. Get the CSRF token. The session cookie is sent automatically by the jar.
    const csrfResponse = await client.get(`${SUPERSET_URL}/api/v1/security/csrf_token/`, {
      headers: {
        'Authorization': `Bearer ${access_token}`,
      },
    });
    const csrfToken = csrfResponse.data.result;

    // 3. Get the guest token. The session cookie is sent automatically.
    const guestTokenResponse = await client.post(
      `${SUPERSET_URL}/api/v1/security/guest_token/`,
      {
        user: {
          username: 'guest',
          first_name: 'Guest',
          last_name: 'User',
        },
        rls: [],
        resources: [{
          type: 'dashboard',
          id: DASHBOARD_ID,
        }],
      },
      {
        headers: {
          'Authorization': `Bearer ${access_token}`,
          'X-CSRFToken': csrfToken,
        },
      }
    );

    const { token } = guestTokenResponse.data;
    res.json({ guestToken: token });

  } catch (error) {
    console.error('Full error:', error.response ? error.response.data : error.message);
    res.status(500).send(error.response ? error.response.data : error.message);
  }
});

app.listen(port, () => {
  console.log(`Server listening at http://localhost:${port}`);
});
