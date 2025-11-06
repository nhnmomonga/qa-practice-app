#!/bin/bash
echo "=== 最終セキュリティチェック ==="

# Test: ハードコードされたシークレットキー
echo "[TEST 21] シークレットキーのハードコード確認"
if grep -q "secret_key = '" /home/runner/work/qa-practice-app/qa-practice-app/app.py; then
    SECRET=$(grep "secret_key = " /home/runner/work/qa-practice-app/qa-practice-app/app.py | head -1)
    echo "  結果: 【重大な脆弱性】シークレットキーがハードコードされている"
    echo "  詳細: $SECRET"
    echo "  影響: セッション改ざん、署名の偽造が可能"
else
    echo "  結果: シークレットキーは環境変数から読み込まれている（適切）"
fi

# Test: SQLiteデータベースファイルのアクセス権
echo ""
echo "[TEST 22] データベースファイルの直接アクセス"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000/database.db)
if [ "$STATUS" == "200" ]; then
    echo "  結果: 【重大な脆弱性】データベースファイルが直接ダウンロード可能"
elif [ "$STATUS" == "404" ]; then
    echo "  結果: アクセス不可（適切）"
else
    echo "  結果: ステータス $STATUS"
fi

# Test: Debugピンの露出
echo ""
echo "[TEST 23] デバッグピンの露出確認"
echo "  app.pyログからデバッグピンを確認..."
if grep -q "Debugger PIN:" /tmp/app3.log 2>/dev/null; then
    PIN=$(grep "Debugger PIN:" /tmp/app3.log | tail -1)
    echo "  結果: 【重大な脆弱性】デバッグモードが有効"
    echo "  詳細: $PIN"
    echo "  影響: デバッガーコンソールへのアクセスでリモートコード実行が可能"
else
    echo "  結果: デバッグモード無効（適切）"
fi

# Test: パスワードのハッシュ化
echo ""
echo "[TEST 24] パスワード保存方法の確認"
echo "  app.pyでのパスワード管理を確認..."
if grep -q "USERS = {" /home/runner/work/qa-practice-app/qa-practice-app/app.py; then
    echo "  結果: 【重大な脆弱性】パスワードが平文で保存されている"
    echo "  詳細: USERS辞書に平文パスワードが記載"
    echo "  影響: ソースコード漏洩時に全アカウントが侵害される"
else
    echo "  結果: パスワードはハッシュ化されている（適切）"
fi

# Test: エラーページでの情報漏洩（500エラー）
echo ""
echo "[TEST 25] 500エラーページの情報漏洩"
curl -s -c user_cookies.txt -d "username=user" -d "password=user_password" http://127.0.0.1:5000/login > /dev/null
RESULT=$(curl -s -b user_cookies.txt "http://127.0.0.1:5000/products?keyword=バグ票")
if echo "$RESULT" | grep -q "Traceback\|File \"/\|line [0-9]"; then
    echo "  結果: 【脆弱性】スタックトレースが露出"
    echo "  影響: ファイルパス、ライブラリバージョンなど内部情報が漏洩"
    # スタックトレースの一部を保存
    echo "$RESULT" | grep -A 5 "Traceback" > stacktrace_sample.txt
else
    echo "  結果: スタックトレースは隠蔽されている"
fi

echo ""
echo "=== 最終セキュリティチェック完了 ==="
