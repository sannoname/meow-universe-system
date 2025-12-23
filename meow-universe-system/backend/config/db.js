const { Pool } = require('pg');

// 這裡會自動讀取 docker-compose.yml 傳進來的環境變數 DATABASE_URL
// 結構為: postgres://使用者:密碼@db:5432/資料庫名
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
});

// 監聽連線事件 (除錯用)
pool.on('connect', () => {
    console.log('✅ 資料庫連線成功 (Connected to DB)');
});

pool.on('error', (err) => {
    console.error('❌ 資料庫連線錯誤 (Unexpected error on idle client)', err);
    process.exit(-1);
});

// 匯出模組供 server.js 使用
module.exports = {
    query: (text, params) => pool.query(text, params),
};