# ISMS 文件庫

需登入才能檢視的 ISMS(ISO 27001:2022)文件網站。架構比照 `clockin`:靜態前端(GitHub Pages)+ Supabase(Auth、RLS、Storage)。

| 檔案 | 用途 |
|------|------|
| `index.html` | 文件總覽:登入後才載入清單;PDF 預覽 / 下載每次都向 Supabase 要 60 秒簽名連結 |
| `admin.html` | 管理後台:批次上傳文件、刪除、維護「可檢視名單」 |
| `schema.sql` | 資料表 + RLS + 私有 Storage bucket `isms` |
| `config.js` | Supabase URL 與 publishable key |

## 為什麼是「真的」需要認證
GitHub Pages 的檔案一律公開,所以**文件本體不放在 repo**,repo 內只有程式。
文件放在 Supabase 私有 bucket,未登入或不在名單內的人,連清單都讀不到(RLS)。

## 部署步驟
1. Supabase SQL Editor 執行 `schema.sql`;並在最後一段把自己設為管理員。
2. Authentication → Providers → Email:**關閉 Allow new users to sign up**。
3. Authentication → Users → Add user:建立管理員與每位檢視者的帳號。
4. 填好 `config.js`,push 到 GitHub,Settings → Pages 啟用。
5. 開啟 `admin.html` 登入 → 上傳文件 → 「可檢視名單」加入檢視者 Email。
