const express = require('express');
const cors = require('cors'); // [新增] 引入 cors
const db = require('./config/db');
const app = express();
const port = process.env.PORT || 3000;

// [新增] 啟用 CORS，允許前端 (8080) 呼叫
app.use(cors());
app.use(express.json());

// API: 測試用，取得所有商家
app.get('/api/merchants', async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM merchants');
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'DB Error' });
    }
});

// API: 測試用，取得所有商品
app.get('/api/products', async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM product_catalog');
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'DB Error' });
    }
});

app.listen(port, () => {
    console.log(`Backend running on port ${port}`);
});