#!/bin/bash

echo "===================================================================================="
echo "探索的セキュリティテストセッション"
echo "開始時刻: $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================================================================="

# ログファイル
LOGFILE="test_notes_manual.txt"
echo "探索的セキュリティテストノート" > $LOGFILE
echo "開始時刻: $(date '+%Y-%m-%d %H:%M:%S')" >> $LOGFILE
echo "" >> $LOGFILE

# Test 1: CSRFトークンの確認
echo ""
echo "[TEST 1] CSRF保護の確認"
echo "$(date '+%H:%M:%S') / 意図: フォームにCSRFトークンがあるか確認 / 入力: GET /login / 観察:" >> $LOGFILE
curl -s http://127.0.0.1:5000/login | grep -i csrf | head -3
if [ $? -eq 0 ]; then
    echo "  結果: CSRFトークンフィールドが見つかりました"
    echo "$(date '+%H:%M:%S') / 観察: CSRFトークンフィールドあり / 洞察: CSRF対策実装済み / 仮説: 検証が必要" >> $LOGFILE
else
    echo "  結果: CSRFトークンフィールドが見つかりません【脆弱性の可能性】"
    echo "$(date '+%H:%M:%S') / 観察: CSRFトークンなし / 洞察: 【脆弱性】CSRF攻撃が可能 / 仮説: CSRFトークン未実装" >> $LOGFILE
fi

# Test 2: SQLインジェクション（ログイン）
echo ""
echo "[TEST 2] SQLインジェクション（ログインフォーム）"
echo "$(date '+%H:%M:%S') / 意図: ログインフォームでSQLインジェクションを試行 / 入力: username=admin' OR '1'='1 / 観察:" >> $LOGFILE
RESULT=$(curl -s -c cookies.txt -d "username=admin' OR '1'='1" -d "password=anything" http://127.0.0.1:5000/login)
if echo "$RESULT" | grep -q "ログインしました"; then
    echo "  結果: ログイン成功【重大な脆弱性】"
    echo "$(date '+%H:%M:%S') / 観察: SQLインジェクションでログイン成功 / 洞察: 【重大な脆弱性】SQLインジェクション脆弱性あり / 仮説: パラメータ化クエリ未使用" >> $LOGFILE
else
    echo "  結果: ログイン失敗（適切に防御されている）"
    echo "$(date '+%H:%M:%S') / 観察: SQLインジェクション失敗 / 洞察: SQLインジェクション対策済み / 仮説: パラメータ化クエリ使用" >> $LOGFILE
fi

# Test 3: 正常ログイン（セッション取得）
echo ""
echo "[TEST 3] 正常ログイン（セッション確保）"
echo "$(date '+%H:%M:%S') / 意図: 正常な管理者ログインでセッション取得 / 入力: admin/admin_password / 観察:" >> $LOGFILE
curl -s -c cookies_admin.txt -d "username=admin" -d "password=admin_password" http://127.0.0.1:5000/login > /dev/null
echo "  結果: セッション取得完了"
echo "$(date '+%H:%M:%S') / 観察: ログイン成功、Cookie取得 / 洞察: セッション管理機能動作中 / 仮説: Flaskセッション使用" >> $LOGFILE

# Test 4: セッションCookieの属性確認
echo ""
echo "[TEST 4] セッションCookieのセキュリティ属性"
echo "$(date '+%H:%M:%S') / 意図: Cookie属性（HttpOnly, Secure, SameSite）の確認 / 入力: Cookie検査 / 観察:" >> $LOGFILE
curl -s -i -b cookies_admin.txt http://127.0.0.1:5000/products | grep -i "set-cookie"
COOKIE_HEADERS=$(curl -s -i -b cookies_admin.txt http://127.0.0.1:5000/products | grep -i "set-cookie")
if echo "$COOKIE_HEADERS" | grep -qi "httponly"; then
    echo "  HttpOnly: あり（適切）"
    echo "$(date '+%H:%M:%S') / 観察: HttpOnly属性あり / 洞察: XSS攻撃からCookie保護 / 仮説: Flask標準のセッション管理" >> $LOGFILE
else
    echo "  HttpOnly: なし【脆弱性】"
    echo "$(date '+%H:%M:%S') / 観察: HttpOnly属性なし / 洞察: 【脆弱性】XSS攻撃でCookie窃取可能 / 仮説: セッション設定の不備" >> $LOGFILE
fi
if echo "$COOKIE_HEADERS" | grep -qi "secure"; then
    echo "  Secure: あり"
    echo "$(date '+%H:%M:%S') / 観察: Secure属性あり / 洞察: HTTPS通信のみでCookie送信 / 仮説: 本番環境を想定" >> $LOGFILE
else
    echo "  Secure: なし（HTTP環境では通常）"
    echo "$(date '+%H:%M:%S') / 観察: Secure属性なし / 洞察: HTTP環境のため妥当だがHTTPS推奨 / 仮説: 開発環境のみ使用を想定" >> $LOGFILE
fi

# Test 5: SQLインジェクション（検索フォーム）
echo ""
echo "[TEST 5] SQLインジェクション（検索フォーム）"
echo "$(date '+%H:%M:%S') / 意図: 検索機能でSQLインジェクションを試行 / 入力: keyword=' OR '1'='1 / 観察:" >> $LOGFILE
RESULT=$(curl -s -b cookies_admin.txt "http://127.0.0.1:5000/products?keyword=%27%20OR%20%271%27%3D%271")
if echo "$RESULT" | grep -qi "internal server error\|traceback\|syntax error"; then
    echo "  結果: エラー発生【SQLインジェクション脆弱性の可能性】"
    echo "$(date '+%H:%M:%S') / 観察: サーバーエラー発生 / 洞察: 【脆弱性】SQLインジェクション可能性 / 仮説: 入力値の不適切な処理" >> $LOGFILE
else
    echo "  結果: エラーなし（適切に防御されている）"
    echo "$(date '+%H:%M:%S') / 観察: 正常レスポンス / 洞察: SQLインジェクション対策済み / 仮説: プレースホルダー使用" >> $LOGFILE
fi

# Test 6: 権限昇格テスト
echo ""
echo "[TEST 6] 権限昇格（一般ユーザーでの削除試行）"
echo "$(date '+%H:%M:%S') / 意図: 一般ユーザーで削除権限をテスト / 入力: user権限で商品削除 / 観察:" >> $LOGFILE
curl -s -c cookies_user.txt -d "username=user" -d "password=user_password" http://127.0.0.1:5000/login > /dev/null
RESULT=$(curl -s -b cookies_user.txt -X POST http://127.0.0.1:5000/products/1/delete)
if echo "$RESULT" | grep -q "削除しました"; then
    echo "  結果: 削除成功【重大な脆弱性】"
    echo "$(date '+%H:%M:%S') / 観察: 一般ユーザーが削除成功 / 洞察: 【重大な脆弱性】権限チェック不備 / 仮説: 認可処理の欠陥" >> $LOGFILE
elif echo "$RESULT" | grep -q "権限がありません"; then
    echo "  結果: 削除拒否（適切な権限管理）"
    echo "$(date '+%H:%M:%S') / 観察: 削除拒否エラー / 洞察: 権限チェック適切 / 仮説: Role-Based Access Control実装" >> $LOGFILE
else
    echo "  結果: 予期しない応答"
    echo "$(date '+%H:%M:%S') / 観察: 不明な応答 / 洞察: 要追加調査 / 仮説: リダイレクトまたはエラー" >> $LOGFILE
fi

# Test 7: パストラバーサル
echo ""
echo "[TEST 7] パストラバーサル攻撃"
echo "$(date '+%H:%M:%S') / 意図: 静的ファイルパスでパストラバーサルをテスト / 入力: /static/../app.py / 観察:" >> $LOGFILE
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000/static/../app.py)
if [ "$STATUS" == "200" ]; then
    echo "  結果: ファイルアクセス成功【重大な脆弱性】"
    echo "$(date '+%H:%M:%S') / 観察: app.pyへのアクセス成功 / 洞察: 【重大な脆弱性】パストラバーサル可能 / 仮説: パス検証不足" >> $LOGFILE
else
    echo "  結果: アクセス拒否（ステータス: $STATUS）"
    echo "$(date '+%H:%M:%S') / 観察: アクセス拒否（$STATUS） / 洞察: パストラバーサル対策済み / 仮説: Flaskの標準防御" >> $LOGFILE
fi

# Test 8: デバッグモード情報漏洩
echo ""
echo "[TEST 8] デバッグ情報の漏洩"
echo "$(date '+%H:%M:%S') / 意図: 存在しないリソースでスタックトレース露出をテスト / 入力: /products/99999/edit / 観察:" >> $LOGFILE
RESULT=$(curl -s -b cookies_admin.txt http://127.0.0.1:5000/products/99999/edit)
if echo "$RESULT" | grep -q "Traceback\|File \""; then
    echo "  結果: スタックトレース露出【脆弱性】"
    echo "$(date '+%H:%M:%S') / 観察: スタックトレース表示 / 洞察: 【脆弱性】内部実装情報が漏洩 / 仮説: debug=True設定" >> $LOGFILE
else
    echo "  結果: スタックトレースなし（適切）"
    echo "$(date '+%H:%M:%S') / 観察: エラーページのみ / 洞察: デバッグ情報は保護されている / 仮説: カスタムエラーハンドラー" >> $LOGFILE
fi

# Test 9: セッション固定化攻撃
echo ""
echo "[TEST 9] セッション固定化攻撃"
echo "$(date '+%H:%M:%S') / 意図: ログイン前後でセッションIDが変更されるか確認 / 入力: セッションID比較 / 観察:" >> $LOGFILE
curl -s -c cookies_before.txt http://127.0.0.1:5000/login > /dev/null
SESSION_BEFORE=$(grep session cookies_before.txt | awk '{print $7}' | head -c 20)
curl -s -b cookies_before.txt -c cookies_after.txt -d "username=admin" -d "password=admin_password" http://127.0.0.1:5000/login > /dev/null
SESSION_AFTER=$(grep session cookies_after.txt | awk '{print $7}' | head -c 20)
if [ "$SESSION_BEFORE" == "$SESSION_AFTER" ] && [ ! -z "$SESSION_BEFORE" ]; then
    echo "  結果: セッションID不変【脆弱性】"
    echo "$(date '+%H:%M:%S') / 観察: セッションID変わらず / 洞察: 【脆弱性】セッション固定化攻撃のリスク / 仮説: セッション再生成なし" >> $LOGFILE
else
    echo "  結果: セッションID変更（適切）"
    echo "$(date '+%H:%M:%S') / 観察: セッションID変更確認 / 洞察: セッション固定化攻撃への対策あり / 仮説: Flask標準動作" >> $LOGFILE
fi

# Test 10: 負の値での商品登録
echo ""
echo "[TEST 10] 入力値検証（負の価格）"
echo "$(date '+%H:%M:%S') / 意図: 負の価格で商品登録を試行 / 入力: price=-1000 / 観察:" >> $LOGFILE
RESULT=$(curl -s -b cookies_admin.txt -d "name=テスト商品" -d "category=その他" -d "price=-1000" -d "stock=100" -d "description=test" http://127.0.0.1:5000/products/new)
if echo "$RESULT" | grep -q "エラー\|以下"; then
    echo "  結果: バリデーションエラー（適切）"
    echo "$(date '+%H:%M:%S') / 観察: エラーメッセージ表示 / 洞察: 入力検証は適切 / 仮説: サーバーサイドバリデーション実装" >> $LOGFILE
elif echo "$RESULT" | grep -q "登録しました"; then
    echo "  結果: 登録成功【脆弱性】"
    echo "$(date '+%H:%M:%S') / 観察: 負の価格で登録成功 / 洞察: 【脆弱性】入力検証不足 / 仮説: バリデーション回避可能" >> $LOGFILE
else
    echo "  結果: 不明"
    echo "$(date '+%H:%M:%S') / 観察: 結果不明 / 洞察: 要追加調査 / 仮説: リダイレクトまたはJavaScript依存" >> $LOGFILE
fi

echo ""
echo "===================================================================================="
echo "セッション終了"
echo "終了時刻: $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================================================================="
echo "" >> $LOGFILE
echo "セッション終了時刻: $(date '+%Y-%m-%d %H:%M:%S')" >> $LOGFILE

echo ""
echo "詳細なテストノートは test_notes_manual.txt に保存されました"

