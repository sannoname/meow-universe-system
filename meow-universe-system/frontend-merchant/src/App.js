import React, { useEffect, useState } from 'react';

function App() {
    const [merchants, setMerchants] = useState([]);
    const [products, setProducts] = useState([]);

    useEffect(() => {
        // 1. 呼叫後端 API 取得商家資料
        // 注意：這裡是連線到 'localhost'，因為這是從瀏覽器發出的請求
        fetch('http://localhost:3000/api/merchants')
            .then(res => res.json())
            .then(data => setMerchants(data))
            .catch(err => console.error("Merchant API Error:", err));

        // 2. 呼叫後端 API 取得商品資料
        fetch('http://localhost:3000/api/products')
            .then(res => res.json())
            .then(data => setProducts(data))
            .catch(err => console.error("Product API Error:", err));
    }, []);

    return (
        <div style={{ padding: '20px', fontFamily: 'Arial' }}>
            <h1>🐱 喵比商家控制台 (Merchant Console)</h1>
            <hr />

            <h3>🏪 店鋪資訊 (來自資料庫)</h3>
            {merchants.length > 0 ? (
                merchants.map(m => (
                    <div key={m.id}>
                        <p><b>ID:</b> {m.id}</p>
                        <p><b>店名:</b> {m.merchant_name}</p>
                        <p><b>最低訂單額:</b> {m.min_order_value}</p>
                    </div>
                ))
            ) : (<p>載入中或無資料...</p>)}

            <hr />

            <h3>📦 商品監控 (來自資料庫)</h3>
            {products.length > 0 ? (
                <ul>
                    {products.map(p => (
                        <li key={p.id}>[{p.status}] {p.title}</li>
                    ))}
                </ul>
            ) : (<p>目前沒有監控商品...</p>)}
        </div>
    );
}

export default App;