import React, { useState, useEffect } from 'react';
import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000';

function App() {
  const [token, setToken] = useState(localStorage.getItem('token') || '');
  const [email, setEmail] = useState(localStorage.getItem('email') || '');
  const [role, setRole] = useState(localStorage.getItem('role') || '');

  // Login form state
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [loginError, setLoginError] = useState('');

  // Dashboard views: 'analytics' | 'sessions' | 'users'
  const [activeTab, setActiveTab] = useState('analytics');

  // Paginated sessions log state
  const [sessions, setSessions] = useState([]);
  const [sessionsCount, setSessionsCount] = useState(0);
  const [sessionsLimit] = useState(8);
  const [sessionsOffset, setSessionsOffset] = useState(0);
  const [searchQuery, setSearchQuery] = useState('');
  const [loadingSessions, setLoadingSessions] = useState(false);

  // All sessions for computing dashboard analytics (unpaginated/higher limit sample)
  const [allSessionsForAnalytics, setAllSessionsForAnalytics] = useState([]);
  const [loadingAnalytics, setLoadingAnalytics] = useState(false);

  // Selected session for detail modal
  const [selectedSession, setSelectedSession] = useState(null);
  const [videoUrl, setVideoUrl] = useState('');
  const [loadingVideo, setLoadingVideo] = useState(false);

  // Users log state
  const [users, setUsers] = useState([]);
  const [loadingUsers, setLoadingUsers] = useState(false);

  // Invite states
  const [generatedInvite, setGeneratedInvite] = useState('');
  const [loadingInvite, setLoadingInvite] = useState(false);
  const [inviteCopied, setInviteCopied] = useState(false);

  // Secondary user registration state
  const [regEmail, setRegEmail] = useState('');
  const [regPassword, setRegPassword] = useState('');
  const [regInviteCode, setRegInviteCode] = useState('');
  const [regSuccess, setRegSuccess] = useState('');
  const [regError, setRegError] = useState('');

  // Set Auth Header
  const getAuthHeaders = () => ({
    headers: { Authorization: `Bearer ${token}` }
  });

  // Handle Login
  const handleLogin = async (e) => {
    e.preventDefault();
    setLoginError('');
    try {
      const response = await axios.post(`${API_BASE_URL}/api/v1/auth/login`, {
        email: loginEmail,
        password: loginPassword,
      });
      const { access_token, email: userEmail, role: userRole } = response.data;
      
      localStorage.setItem('token', access_token);
      localStorage.setItem('email', userEmail);
      localStorage.setItem('role', userRole);
      
      setToken(access_token);
      setEmail(userEmail);
      setRole(userRole);
      setActiveTab('analytics');
    } catch (err) {
      setLoginError(err.response?.data?.detail || 'Authentication failed. Please check credentials.');
    }
  };

  // Handle Logout
  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('email');
    localStorage.removeItem('role');
    setToken('');
    setEmail('');
    setRole('');
    setSelectedSession(null);
  };

  // Load Paginated Sessions
  const fetchSessions = async () => {
    if (!token) return;
    setLoadingSessions(true);
    try {
      const response = await axios.get(`${API_BASE_URL}/api/v1/liveness/sessions`, {
        params: {
          limit: sessionsLimit,
          offset: sessionsOffset,
          search: searchQuery || undefined
        },
        ...getAuthHeaders()
      });
      setSessions(response.data.sessions);
      setSessionsCount(response.data.total);
    } catch (err) {
      console.error('Failed to load sessions', err);
    } finally {
      setLoadingSessions(false);
    }
  };

  // Fetch all sessions for Analytics computations (fetches a larger sample size, e.g., 200 records)
  const fetchAnalyticsData = async () => {
    if (!token) return;
    setLoadingAnalytics(true);
    try {
      const response = await axios.get(`${API_BASE_URL}/api/v1/liveness/sessions`, {
        params: {
          limit: 200,
          offset: 0
        },
        ...getAuthHeaders()
      });
      setAllSessionsForAnalytics(response.data.sessions);
    } catch (err) {
      console.error('Failed to load analytics sessions', err);
    } finally {
      setLoadingAnalytics(false);
    }
  };

  // Load Users
  const fetchUsers = async () => {
    if (!token) return;
    setLoadingUsers(true);
    try {
      const response = await axios.get(`${API_BASE_URL}/api/v1/auth/users`, getAuthHeaders());
      setUsers(response.data);
    } catch (err) {
      console.error('Failed to load users', err);
    } finally {
      setLoadingUsers(false);
    }
  };

  // Fetch pre-signed S3 URL for session replay
  const loadSessionVideo = async (sessionId) => {
    setVideoUrl('');
    setLoadingVideo(true);
    try {
      const response = await axios.get(
        `${API_BASE_URL}/api/v1/liveness/session/${sessionId}/video`,
        getAuthHeaders()
      );
      setVideoUrl(response.data.url);
    } catch (err) {
      console.warn('Video not available or failed to load:', err.response?.data?.detail);
    } finally {
      setLoadingVideo(false);
    }
  };

  // Generate Invite Code
  const generateInvite = async () => {
    setLoadingInvite(true);
    setGeneratedInvite('');
    setInviteCopied(false);
    try {
      const response = await axios.post(`${API_BASE_URL}/api/v1/auth/invite`, {}, getAuthHeaders());
      setGeneratedInvite(response.data.code);
    } catch (err) {
      console.error('Failed to generate invite', err);
    } finally {
      setLoadingInvite(false);
    }
  };

  // Copy Invite to Clipboard
  const copyInviteToClipboard = () => {
    if (!generatedInvite) return;
    navigator.clipboard.writeText(generatedInvite);
    setInviteCopied(true);
    setTimeout(() => setInviteCopied(false), 2000);
  };

  // Register New Admin User
  const handleRegister = async (e) => {
    e.preventDefault();
    setRegSuccess('');
    setRegError('');
    try {
      await axios.post(`${API_BASE_URL}/api/v1/auth/register`, {
        email: regEmail,
        password: regPassword,
        invite_code: regInviteCode
      });
      setRegSuccess('New administrator registered successfully!');
      setRegEmail('');
      setRegPassword('');
      setRegInviteCode('');
      fetchUsers();
    } catch (err) {
      setRegError(err.response?.data?.detail || 'Registration failed.');
    }
  };

  // Trigger loading details
  const openSessionDetails = (session) => {
    setSelectedSession(session);
    loadSessionVideo(session.session_id);
  };

  // Effects
  useEffect(() => {
    if (token) {
      fetchSessions();
    }
  }, [token, sessionsOffset, searchQuery]);

  useEffect(() => {
    if (token) {
      if (activeTab === 'analytics') {
        fetchAnalyticsData();
      } else if (activeTab === 'users') {
        fetchUsers();
      }
    }
  }, [token, activeTab]);

  // Dynamically compute stats from real loaded records
  const totalVerifications = allSessionsForAnalytics.length;
  const passedSessions = allSessionsForAnalytics.filter(s => s.status === 'PASS').length;
  const passRate = totalVerifications > 0 ? ((passedSessions / totalVerifications) * 100).toFixed(1) : '0.0';
  const failedSessions = allSessionsForAnalytics.filter(s => s.status === 'FAIL' || s.status === 'LOW_CONFIDENCE').length;
  const totalConfidence = allSessionsForAnalytics.reduce((sum, s) => sum + s.confidence, 0);
  const avgConfidence = totalVerifications > 0 ? (totalConfidence / totalVerifications).toFixed(1) : '0.0';

  // Provider breakdown
  const googleCount = allSessionsForAnalytics.filter(s => s.provider === 'google_ml_kit').length;
  const awsCount = allSessionsForAnalytics.filter(s => s.provider.includes('aws') || s.provider.includes('mock')).length; // remaining custom/AWS models
  const googlePercent = totalVerifications > 0 ? Math.round((googleCount / totalVerifications) * 100) : 0;
  const awsPercent = totalVerifications > 0 ? Math.round((awsCount / totalVerifications) * 100) : 0;

  // Mode breakdown
  const activeCount = allSessionsForAnalytics.filter(s => s.liveness_mode === 'ACTIVE').length;
  const passiveCount = allSessionsForAnalytics.filter(s => s.liveness_mode === 'PASSIVE').length;
  const activePercent = totalVerifications > 0 ? Math.round((activeCount / totalVerifications) * 100) : 0;
  const passivePercent = totalVerifications > 0 ? Math.round((passiveCount / totalVerifications) * 100) : 0;

  // Onboarding vs Verification counts
  const onboardingCount = allSessionsForAnalytics.filter(s => s.verification_type === 'ONBOARDING').length;
  const verificationCount = allSessionsForAnalytics.filter(s => s.verification_type === 'VERIFICATION').length;
  const onboardingPercent = totalVerifications > 0 ? Math.round((onboardingCount / totalVerifications) * 100) : 0;
  const verificationPercent = totalVerifications > 0 ? Math.round((verificationCount / totalVerifications) * 100) : 0;

  // Channel counts
  const personalCount = allSessionsForAnalytics.filter(s => s.channel === 'personal').length;
  const businessCount = allSessionsForAnalytics.filter(s => s.channel === 'business').length;
  const personalPercent = totalVerifications > 0 ? Math.round((personalCount / totalVerifications) * 100) : 0;
  const businessPercent = totalVerifications > 0 ? Math.round((businessCount / totalVerifications) * 100) : 0;

  // Face Match outcomes (for VERIFICATION sessions only)
  const verificationSessions = allSessionsForAnalytics.filter(s => s.verification_type === 'VERIFICATION');
  const matchCount = verificationSessions.filter(s => s.face_match_status === 'MATCH').length;
  const mismatchCount = verificationSessions.filter(s => s.face_match_status === 'MISMATCH').length;
  const totalVerSessionCount = verificationSessions.length;
  const matchPercent = totalVerSessionCount > 0 ? Math.round((matchCount / totalVerSessionCount) * 100) : 0;
  const mismatchPercent = totalVerSessionCount > 0 ? Math.round((mismatchCount / totalVerSessionCount) * 100) : 0;

  // Process data for trend charts (last 7 days counts)
  const getDailyTrendData = () => {
    const data = {};
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
      data[key] = 0;
    }

    allSessionsForAnalytics.forEach(s => {
      const dateStr = new Date(s.created_at * 1000).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
      if (data[dateStr] !== undefined) {
        data[dateStr] += 1;
      }
    });

    const list = Object.entries(data).map(([label, count]) => ({ label, count }));
    const maxVal = Math.max(...list.map(o => o.count), 1);
    return list.map(item => ({
      ...item,
      percentage: Math.max(Math.round((item.count / maxVal) * 100), 5) // ensure at least 5% bar height for styling
    }));
  };

  // Render Login Card
  if (!token) {
    return (
      <div className="login-card-container">
        <div className="glass-panel login-card">
          <div className="login-logo-container">
            <div className="login-logo">
              <i className="material-icons">shield</i>
            </div>
            <h2>FaceGuard</h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '14px', fontWeight: 600 }}>
              Biometric Liveness Audit Hub
            </p>
          </div>

          <form onSubmit={handleLogin}>
            {loginError && (
              <div className="alert-banner error">
                <i className="material-icons">error_outline</i>
                <span>{loginError}</span>
              </div>
            )}

            <div className="form-group">
              <label htmlFor="email">Admin Email Address</label>
              <input
                id="email"
                type="email"
                className="form-control"
                placeholder="admin@kolomoni.com"
                required
                value={loginEmail}
                onChange={(e) => setLoginEmail(e.target.value)}
              />
            </div>

            <div className="form-group" style={{ marginBottom: '28px' }}>
              <label htmlFor="password">Security Password</label>
              <input
                id="password"
                type="password"
                className="form-control"
                placeholder="••••••••••••"
                required
                value={loginPassword}
                onChange={(e) => setLoginPassword(e.target.value)}
              />
            </div>

            <button type="submit" className="btn-primary" style={{ width: '100%' }}>
              <i className="material-icons" style={{ fontSize: '20px' }}>vpn_key</i>
              Authenticate Access
            </button>
          </form>
        </div>
      </div>
    );
  }

  // Helper to render Pagination
  const renderPaginationControls = () => {
    const totalPages = Math.ceil(sessionsCount / sessionsLimit);
    if (totalPages <= 1) return null;

    const currentPage = Math.floor(sessionsOffset / sessionsLimit) + 1;
    const pages = [];
    for (let i = 1; i <= totalPages; i++) {
      pages.push(i);
    }

    return (
      <div className="pagination-container">
        <div className="pagination-info">
          Showing {sessionsOffset + 1} to {Math.min(sessionsOffset + sessionsLimit, sessionsCount)} of {sessionsCount} audits
        </div>
        <div className="pagination-nav">
          <button
            className="pagination-btn"
            disabled={currentPage === 1}
            onClick={() => setSessionsOffset((currentPage - 2) * sessionsLimit)}
          >
            <i className="material-icons" style={{ fontSize: '18px' }}>chevron_left</i>
          </button>
          {pages.map((p) => (
            <button
              key={p}
              className={`pagination-btn ${currentPage === p ? 'active' : ''}`}
              onClick={() => setSessionsOffset((p - 1) * sessionsLimit)}
            >
              {p}
            </button>
          ))}
          <button
            className="pagination-btn"
            disabled={currentPage === totalPages}
            onClick={() => setSessionsOffset(currentPage * sessionsLimit)}
          >
            <i className="material-icons" style={{ fontSize: '18px' }}>chevron_right</i>
          </button>
        </div>
      </div>
    );
  };

  // Render Full Dashboard Layout
  return (
    <div className="app-container">
      {/* Header */}
      <header className="app-header">
        <div className="header-container">
          <a href="#!" className="brand">
            <div className="brand-icon">
              <i className="material-icons" style={{ fontSize: '24px' }}>shield</i>
            </div>
            <span>FaceGuard</span>
          </a>

          {/* Navigation Controls */}
          <div className="nav-tabs">
            <button
              className={`nav-tab-btn ${activeTab === 'analytics' ? 'active' : ''}`}
              onClick={() => setActiveTab('analytics')}
            >
              <i className="material-icons">insights</i>
              Analytics
            </button>
            <button
              className={`nav-tab-btn ${activeTab === 'sessions' ? 'active' : ''}`}
              onClick={() => {
                setActiveTab('sessions');
                setSessionsOffset(0);
              }}
            >
              <i className="material-icons">history</i>
              Biometric Audits
            </button>
            <button
              className={`nav-tab-btn ${activeTab === 'users' ? 'active' : ''}`}
              onClick={() => setActiveTab('users')}
            >
              <i className="material-icons">admin_panel_settings</i>
              Admin Panel
            </button>
          </div>

          {/* User Section */}
          <div className="user-profile">
            <div className="user-info">
              <div className="user-email">{email}</div>
              <div className="user-role">{role}</div>
            </div>
            <button className="btn-logout" onClick={handleLogout}>
              <i className="material-icons">logout</i>
              Sign Out
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Pane */}
      <main className="main-content">
        {activeTab === 'analytics' && (
          <div className="tab-pane">
            <h3 style={{ marginBottom: '24px' }}>Security & Telemetry Analytics</h3>

            {/* Metrics cards grid */}
            <div className="grid-cols-4" style={{ marginBottom: '32px' }}>
              <div className="glass-panel stat-card">
                <div className="stat-icon primary">
                  <i className="material-icons">fingerprint</i>
                </div>
                <div className="stat-details">
                  <div className="stat-value">{loadingAnalytics ? '...' : totalVerifications}</div>
                  <div className="stat-label">Total Audits</div>
                </div>
              </div>

              <div className="glass-panel stat-card">
                <div className="stat-icon success">
                  <i className="material-icons">check_circle</i>
                </div>
                <div className="stat-details">
                  <div className="stat-value">{loadingAnalytics ? '...' : `${passRate}%`}</div>
                  <div className="stat-label">Success Rate</div>
                </div>
              </div>

              <div className="glass-panel stat-card">
                <div className="stat-icon danger">
                  <i className="material-icons">gpp_bad</i>
                </div>
                <div className="stat-details">
                  <div className="stat-value">{loadingAnalytics ? '...' : failedSessions}</div>
                  <div className="stat-label">Blocked Threats</div>
                </div>
              </div>

              <div className="glass-panel stat-card">
                <div className="stat-icon info">
                  <i className="material-icons">speed</i>
                </div>
                <div className="stat-details">
                  <div className="stat-value">{loadingAnalytics ? '...' : `${avgConfidence}%`}</div>
                  <div className="stat-label">Avg Confidence</div>
                </div>
              </div>
            </div>

            {/* Graphic widgets section */}
            <div className="grid-cols-3" style={{ marginBottom: '32px' }}>
              {/* Daily Trend widget */}
              <div className="glass-panel col-span-2" style={{ gridColumn: 'span 2' }}>
                <h4 style={{ marginBottom: '16px', fontSize: '18px' }}>Audit Traffic (Last 7 Days)</h4>
                <div className="trends-container">
                  {loadingAnalytics ? (
                    <div style={{ textAlign: 'center', width: '100%', color: 'var(--text-secondary)', paddingBottom: '60px' }}>
                      Gathering session reports...
                    </div>
                  ) : totalVerifications === 0 ? (
                    <div style={{ textAlign: 'center', width: '100%', color: 'var(--text-secondary)', paddingBottom: '60px' }}>
                      No biometric data logs captured yet.
                    </div>
                  ) : (
                    getDailyTrendData().map((item, idx) => (
                      <div className="trend-bar-wrapper" key={idx}>
                        <div
                          className="trend-bar-interactive"
                          style={{ height: `${item.percentage}%` }}
                          data-tooltip={`${item.count} verifications`}
                        ></div>
                        <div className="trend-bar-label">{item.label}</div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Provider breakdown widget */}
              <div className="glass-panel" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <h4 style={{ marginBottom: '6px', fontSize: '18px' }}>Security Modules</h4>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '12px', marginBottom: '16px' }}>
                    Methods and SDK providers distribution.
                  </p>

                  <div className="percentage-widget" style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                    <div className="percentage-row">
                      <div className="percentage-label-row">
                        <span className="percentage-title">Google ML Kit</span>
                        <span>{googlePercent}%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${googlePercent}%`, background: 'var(--accent)' }}></div>
                      </div>
                    </div>

                    <div className="percentage-row">
                      <div className="percentage-label-row">
                        <span className="percentage-title">AWS Rekognition / Mock</span>
                        <span>{awsPercent}%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${awsPercent}%`, background: 'var(--primary)' }}></div>
                      </div>
                    </div>

                    <div className="percentage-row" style={{ marginTop: '4px' }}>
                      <div className="percentage-label-row">
                        <span className="percentage-title">Passive Liveness</span>
                        <span>{passivePercent}%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${passivePercent}%`, background: 'var(--success)' }}></div>
                      </div>
                    </div>

                    <div className="percentage-row">
                      <div className="percentage-label-row">
                        <span className="percentage-title">Active Fallback</span>
                        <span>{activePercent}%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${activePercent}%`, background: 'var(--info)' }}></div>
                      </div>
                    </div>
                  </div>
                </div>

                <div style={{ borderTop: '1px solid var(--border)', paddingTop: '16px' }}>
                  <h4 style={{ marginBottom: '6px', fontSize: '18px' }}>Flows & Channels</h4>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '12px', marginBottom: '16px' }}>
                    Enrollment type & business channel distributions.
                  </p>

                  <div className="percentage-widget" style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                    <div className="percentage-row">
                      <div className="percentage-label-row">
                        <span className="percentage-title">Onboarding</span>
                        <span>{onboardingPercent}%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${onboardingPercent}%`, background: 'var(--accent)' }}></div>
                      </div>
                    </div>

                    <div className="percentage-row">
                      <div className="percentage-label-row">
                        <span className="percentage-title">Verification</span>
                        <span>{verificationPercent}%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${verificationPercent}%`, background: 'var(--primary-hover)' }}></div>
                      </div>
                    </div>

                    <div className="percentage-row" style={{ marginTop: '4px' }}>
                      <div className="percentage-label-row">
                        <span className="percentage-title">Personal Channel</span>
                        <span>{personalPercent}%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${personalPercent}%`, background: 'var(--success)' }}></div>
                      </div>
                    </div>

                    <div className="percentage-row">
                      <div className="percentage-label-row">
                        <span className="percentage-title">Business Channel</span>
                        <span>{businessPercent}%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${businessPercent}%`, background: 'var(--info)' }}></div>
                      </div>
                    </div>

                    {totalVerSessionCount > 0 && (
                      <div className="percentage-row" style={{ marginTop: '4px', background: 'rgba(15,23,42,0.02)', padding: '10px', borderRadius: '8px', border: '1px solid var(--border)' }}>
                        <div className="percentage-label-row">
                          <span className="percentage-title" style={{ color: 'var(--primary-dark)' }}>Face Match success</span>
                          <span style={{ color: 'var(--success)' }}>{matchPercent}%</span>
                        </div>
                        <div className="progress-bar" style={{ height: '6px', marginTop: '6px' }}>
                          <div className="progress-fill" style={{ width: `${matchPercent}%`, background: 'var(--success)' }}></div>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Audits Logs view */}
        {activeTab === 'sessions' && (
          <div className="tab-pane">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '15px' }}>
              <div>
                <h3>Biometric Verification Logs</h3>
                <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginTop: '4px' }}>
                  Analyze biometric verification telemetry, pre-signed video replays, and security metrics.
                </p>
              </div>

              {/* Inline outline search input */}
              <div className="search-container">
                <i className="material-icons search-icon">search</i>
                <input
                  type="text"
                  className="search-input"
                  placeholder="Search User ID or BVN..."
                  value={searchQuery}
                  onChange={(e) => {
                    setSearchQuery(e.target.value);
                    setSessionsOffset(0);
                  }}
                />
              </div>
            </div>

            {/* Log Table Container */}
            <div className="glass-panel" style={{ padding: '8px' }}>
              {loadingSessions ? (
                <div style={{ textAlign: 'center', padding: '60px', color: 'var(--text-secondary)' }}>
                  <i className="material-icons" style={{ fontSize: '36px', display: 'block', marginBottom: '12px', color: 'var(--accent)' }}>sync</i>
                  Syncing logs with Postgres...
                </div>
              ) : sessions.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '60px', color: 'var(--text-secondary)' }}>
                  <i className="material-icons" style={{ fontSize: '48px', marginBottom: '12px' }}>find_in_page</i>
                  <p>No verification logs found matching the query criteria.</p>
                </div>
              ) : (
                <div className="table-wrapper">
                  <table className="custom-table">
                    <thead>
                      <tr>
                        <th>Session ID</th>
                        <th>User ID</th>
                        <th>BVN</th>
                        <th>Type</th>
                        <th>Channel</th>
                        <th>Provider</th>
                        <th>Status</th>
                        <th>Confidence</th>
                        <th>Timestamp</th>
                        <th style={{ textAlign: 'right' }}>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {sessions.map((s) => (
                        <tr key={s.session_id}>
                          <td style={{ fontFamily: 'monospace', fontSize: '13px' }}>{s.session_id}</td>
                          <td style={{ fontWeight: 700 }}>{s.user_id || 'N/A'}</td>
                          <td style={{ fontWeight: 700, color: 'var(--primary-hover)' }}>{s.bvn || 'N/A'}</td>
                          <td>
                            <span style={{ fontSize: '11px', fontWeight: 700, color: s.verification_type === 'ONBOARDING' ? 'var(--accent)' : 'var(--primary-hover)' }}>
                              {s.verification_type}
                            </span>
                          </td>
                          <td style={{ textTransform: 'capitalize' }}>{s.channel || 'N/A'}</td>
                          <td style={{ textTransform: 'capitalize' }}>{s.provider.replace('_', ' ')}</td>
                          <td>
                            <span className={`badge-status ${s.status.toLowerCase()}`}>
                              {s.status}
                            </span>
                          </td>
                          <td style={{ fontWeight: 700 }}>{s.confidence.toFixed(1)}%</td>
                          <td style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>
                            {new Date(s.created_at * 1000).toLocaleString()}
                          </td>
                          <td style={{ textAlign: 'right' }}>
                            <button
                              className="btn-primary"
                              style={{ padding: '8px 14px', borderRadius: '8px', fontSize: '12px', display: 'inline-flex' }}
                              onClick={() => openSessionDetails(s)}
                            >
                              <i className="material-icons" style={{ fontSize: '16px' }}>play_circle_filled</i>
                              Replay
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
            {renderPaginationControls()}
          </div>
        )}

        {/* Admin controls view */}
        {activeTab === 'users' && (
          <div className="tab-pane">
            <h3 style={{ marginBottom: '24px' }}>Administrative User & Invites Control</h3>

            <div className="grid-cols-3">
              {/* Admins Table */}
              <div className="glass-panel" style={{ gridColumn: 'span 2' }}>
                <h4 style={{ marginBottom: '16px', fontSize: '18px' }}>Security Team Credentials</h4>
                
                {loadingUsers ? (
                  <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                    Loading credentials...
                  </div>
                ) : (
                  <div className="table-wrapper">
                    <table className="custom-table">
                      <thead>
                        <tr>
                          <th>Admin Email Address</th>
                          <th>System Role</th>
                          <th>Enrollment Date</th>
                        </tr>
                      </thead>
                      <tbody>
                        {users.map((u, i) => (
                          <tr key={i}>
                            <td style={{ fontWeight: 700 }}>{u.email}</td>
                            <td>
                              <span style={{ fontSize: '11px', fontWeight: 700, color: 'var(--accent)', textTransform: 'uppercase' }}>
                                {u.role}
                              </span>
                            </td>
                            <td style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>
                              {new Date(u.created_at * 1000).toLocaleDateString()}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>

              {/* Invites & enrollment */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                {/* Invite codes */}
                <div className="glass-panel">
                  <h4 style={{ marginBottom: '8px', fontSize: '18px' }}>One-Time Invites</h4>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '20px' }}>
                    Generate one-time system invitation tokens to register secondary administrator accounts.
                  </p>

                  <button className="btn-primary" style={{ width: '100%' }} onClick={generateInvite} disabled={loadingInvite}>
                    <i className="material-icons" style={{ fontSize: '20px' }}>add_link</i>
                    {loadingInvite ? 'Generating...' : 'Generate New Invite Token'}
                  </button>

                  {generatedInvite && (
                    <div
                      style={{
                        marginTop: '20px',
                        background: 'rgba(34, 199, 214, 0.1)',
                        border: '1px solid rgba(34, 199, 214, 0.25)',
                        borderRadius: '12px',
                        padding: '16px',
                        textAlign: 'center'
                      }}
                    >
                      <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--accent)' }}>
                        Secure Invitation Code
                      </span>
                      <h3 style={{ margin: '6px 0 14px 0', fontSize: '24px', letterSpacing: '1px', fontFamily: 'monospace' }}>
                        {generatedInvite}
                      </h3>
                      <button
                        className="btn-secondary"
                        style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
                        onClick={copyInviteToClipboard}
                      >
                        <i className="material-icons" style={{ fontSize: '18px' }}>
                          {inviteCopied ? 'done' : 'content_copy'}
                        </i>
                        {inviteCopied ? 'Copied Token!' : 'Copy to Clipboard'}
                      </button>
                    </div>
                  )}
                </div>

                {/* Create Admin Form */}
                <div className="glass-panel">
                  <h4 style={{ marginBottom: '16px', fontSize: '18px' }}>Register Admin</h4>
                  <form onSubmit={handleRegister}>
                    {regSuccess && (
                      <div className="alert-banner success" style={{ padding: '10px', fontSize: '13px' }}>
                        <i className="material-icons">check</i>
                        <span>{regSuccess}</span>
                      </div>
                    )}
                    {regError && (
                      <div className="alert-banner error" style={{ padding: '10px', fontSize: '13px' }}>
                        <i className="material-icons">error</i>
                        <span>{regError}</span>
                      </div>
                    )}

                    <div className="form-group">
                      <label htmlFor="regEmail">New Email Address</label>
                      <input
                        id="regEmail"
                        type="email"
                        className="form-control"
                        placeholder="newadmin@example.com"
                        required
                        value={regEmail}
                        onChange={(e) => setRegEmail(e.target.value)}
                      />
                    </div>

                    <div className="form-group">
                      <label htmlFor="regPassword">Security Password</label>
                      <input
                        id="regPassword"
                        type="password"
                        className="form-control"
                        placeholder="Min 8 characters"
                        required
                        value={regPassword}
                        onChange={(e) => setRegPassword(e.target.value)}
                      />
                    </div>

                    <div className="form-group" style={{ marginBottom: '20px' }}>
                      <label htmlFor="regInvite">Invitation Invite Token</label>
                      <input
                        id="regInvite"
                        type="text"
                        className="form-control"
                        placeholder="Paste invite code"
                        required
                        value={regInviteCode}
                        onChange={(e) => setRegInviteCode(e.target.value)}
                      />
                    </div>

                    <button type="submit" className="btn-primary" style={{ width: '100%' }}>
                      Enroll New Admin
                    </button>
                  </form>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Verification Details Overlay Modal */}
      {selectedSession && (
        <>
          <div className="modal-overlay" onClick={() => setSelectedSession(null)}></div>
          <div className="custom-modal">
            <div className="modal-header">
              <h4 style={{ margin: 0 }}>Biometric Session Audit Details</h4>
              <button
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)' }}
                onClick={() => setSelectedSession(null)}
              >
                <i className="material-icons">close</i>
              </button>
            </div>

            <div className="modal-body">
              <div className="grid-cols-3">
                {/* Replay Video Player */}
                <div style={{ gridColumn: 'span 2' }}>
                  <h5 style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '10px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                    Verification Replay
                  </h5>
                  <div
                    style={{
                      width: '100%',
                      background: '#0a0d14',
                      borderRadius: '12px',
                      minHeight: '320px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      overflow: 'hidden',
                      border: '1px solid var(--border)'
                    }}
                  >
                    {loadingVideo ? (
                      <div style={{ color: 'var(--accent)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px' }}>
                        <i className="material-icons animate-spin" style={{ fontSize: '32px' }}>sync</i>
                        <span>Fetching recording from S3...</span>
                      </div>
                    ) : videoUrl ? (
                      <video
                        controls
                        width="100%"
                        height="auto"
                        src={videoUrl}
                        style={{ display: 'block', maxHeight: '380px' }}
                      />
                    ) : (
                      <div style={{ color: 'var(--text-secondary)', textAlign: 'center', padding: '24px' }}>
                        <i className="material-icons" style={{ fontSize: '48px', color: 'rgba(255, 255, 255, 0.15)', marginBottom: '8px' }}>videocam_off</i>
                        <p style={{ fontSize: '13px' }}>No session recording found on S3.</p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Audit details stats */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <h5 style={{ fontSize: '14px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                    Audit Diagnostics
                  </h5>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '13px' }}>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Session ID:</div>
                      <div style={{ fontFamily: 'monospace', fontWeight: 700, wordBreak: 'break-all' }}>{selectedSession.session_id}</div>
                    </div>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Customer ID:</div>
                      <div style={{ fontWeight: 700, fontSize: '14px' }}>{selectedSession.user_id || 'N/A'}</div>
                    </div>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>BVN:</div>
                      <div style={{ fontWeight: 700, fontSize: '14px', color: 'var(--primary-hover)' }}>{selectedSession.bvn || 'N/A'}</div>
                    </div>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Verification Type:</div>
                      <div style={{ fontWeight: 700, textTransform: 'uppercase', color: selectedSession.verification_type === 'ONBOARDING' ? 'var(--accent)' : 'var(--primary-hover)' }}>
                        {selectedSession.verification_type}
                      </div>
                    </div>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Channel Segment:</div>
                      <div style={{ fontWeight: 700, textTransform: 'capitalize' }}>{selectedSession.channel || 'N/A'}</div>
                    </div>
                    {selectedSession.verification_type === 'VERIFICATION' && (
                      <>
                        <div>
                          <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Face Match Decision:</div>
                          <div style={{ marginTop: '4px' }}>
                            {selectedSession.face_match_status ? (
                              <span className={`badge-status ${selectedSession.face_match_status === 'MATCH' ? 'pass' : 'fail'}`}>
                                {selectedSession.face_match_status}
                              </span>
                            ) : (
                              <span className="badge-status warn">PENDING</span>
                            )}
                          </div>
                        </div>
                        {selectedSession.face_match_confidence !== null && selectedSession.face_match_confidence !== undefined && (
                          <div>
                            <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Face Match Similarity:</div>
                            <div style={{ fontWeight: 800, fontSize: '15px', color: 'var(--accent)' }}>
                              {selectedSession.face_match_confidence.toFixed(1)}%
                            </div>
                          </div>
                        )}
                      </>
                    )}
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Provider:</div>
                      <div style={{ fontWeight: 700, textTransform: 'capitalize' }}>{selectedSession.provider.replace('_', ' ')}</div>
                    </div>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Liveness Mode:</div>
                      <div style={{ fontWeight: 700 }}>{selectedSession.liveness_mode}</div>
                    </div>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Outcome:</div>
                      <div style={{ marginTop: '4px' }}>
                        <span className={`badge-status ${selectedSession.status.toLowerCase()}`}>
                          {selectedSession.status}
                        </span>
                      </div>
                    </div>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Match Confidence:</div>
                      <div style={{ fontWeight: 800, fontSize: '16px', color: 'var(--primary-hover)' }}>{selectedSession.confidence.toFixed(1)}%</div>
                    </div>
                    <div>
                      <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Timestamp:</div>
                      <div style={{ fontWeight: 700 }}>{new Date(selectedSession.created_at * 1000).toLocaleString()}</div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Telemetry panel */}
              <div style={{ marginTop: '24px', paddingTop: '20px', borderTop: '1px solid var(--border)' }}>
                <h5 style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '12px', textTransform: 'uppercase', letterSpacing: '0.5px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <i className="material-icons" style={{ fontSize: '18px', color: 'var(--accent)' }}>security</i>
                  Device & Fraud Intelligence Telemetry
                </h5>

                {selectedSession.device_intelligence ? (
                  (() => {
                    try {
                      const tel = JSON.parse(selectedSession.device_intelligence);
                      return (
                        <div
                          style={{
                            display: 'grid',
                            gridTemplateColumns: 'repeat(3, 1fr)',
                            gap: '16px',
                            background: 'var(--surface-alt)',
                            padding: '16px',
                            borderRadius: '12px',
                            border: '1px solid var(--border)'
                          }}
                        >
                          <div>
                            <span style={{ color: 'var(--text-secondary)', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase' }}>Device ID</span>
                            <div style={{ fontFamily: 'monospace', fontSize: '12px', wordBreak: 'break-all', fontWeight: 700, marginTop: '2px' }}>{tel.device_id || 'N/A'}</div>
                          </div>
                          <div>
                            <span style={{ color: 'var(--text-secondary)', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase' }}>Device Model</span>
                            <div style={{ fontWeight: 700, marginTop: '2px' }}>{tel.device_model || 'N/A'}</div>
                          </div>
                          <div>
                            <span style={{ color: 'var(--text-secondary)', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase' }}>OS Version</span>
                            <div style={{ fontWeight: 700, marginTop: '2px' }}>{tel.device_os || 'N/A'}</div>
                          </div>
                          <div style={{ marginTop: '8px' }}>
                            <span style={{ color: 'var(--text-secondary)', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase' }}>IP Address</span>
                            <div style={{ fontFamily: 'monospace', fontWeight: 700, marginTop: '2px' }}>{tel.ip_address || 'N/A'}</div>
                          </div>
                          <div style={{ marginTop: '8px' }}>
                            <span style={{ color: 'var(--text-secondary)', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase' }}>Geo-Coordinates</span>
                            <div style={{ fontWeight: 700, marginTop: '2px' }}>{tel.latitude && tel.longitude ? `(${tel.latitude}, ${tel.longitude})` : 'N/A'}</div>
                          </div>
                        </div>
                      );
                    } catch (e) {
                      return <div style={{ color: 'var(--text-secondary)' }}>Failed to parse device intelligence telemetry.</div>;
                    }
                  })()
                ) : (
                  <div style={{ color: 'var(--text-secondary)', fontSize: '13px', fontStyle: 'italic' }}>
                    No security telemetry was captured for this session.
                  </div>
                )}
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn-secondary" onClick={() => setSelectedSession(null)}>
                Dismiss Audit Panel
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

export default App;
