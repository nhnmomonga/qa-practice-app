#!/bin/bash
echo "=== 追加のセキュリティテスト ==="

# Test: HTTPヘッダーのセキュリティ
echo "[TEST 11] セキュリティHTTPヘッダーの確認"
curl -s -I -b admin_cookies.txt http://127.0.0.1:5000/products > headers.txt
echo "  X-Frame-Options:" $(grep -i "X-Frame-Options" headers.txt || echo "なし【脆弱性】")
echo "  X-Content-Type-Options:" $(grep -i "X-Content-Type-Options" headers.txt || echo "なし【脆弱性】")
echo "  X-XSS-Protection:" $(grep -i "X-XSS-Protection" headers.txt || echo "なし【警告】")
echo "  Content-Security-Policy:" $(grep -i "Content-Security-Policy" headers.txt || echo "なし【警告】")
echo "  Strict-Transport-Security:" $(grep -i "Strict-Transport-Security" headers.txt || echo "なし（HTTP環境のため妥当）")

# Test: 価格操作（クライアントサイド検証回避）
echo ""
echo "[TEST 12] クライアントサイド検証のバイパス"
curl -s -c admin2_cookies.txt -d "username=admin" -d "password=admin_password" http://127.0.0.1:5000/login > /dev/null
RESULT=$(curl -s -b admin2_cookies.txt -d "name=テスト商品XSS" \
  -d "category=その他" \
  -d "price=99999999999" \
  -d "stock=5000" \
  -d "description=test" \
  http://127.0.0.1:5000/products/new)
if echo "$RESULT" | grep -q "登録しました"; then
    echo "  結果: 【脆弱性】極端に大きい価格で登録成功"
    echo "  影響: クライアントサイド検証のみでサーバー側検証不足"
elif echo "$RESULT" | grep -q "エラー\|以下"; then
    echo "  結果: サーバー側検証が機能（適切）"
fi

# Test: 在庫数の極端な値
echo ""
echo "[TEST 13] 在庫数の極端な値"
RESULT=$(curl -s -b admin2_cookies.txt -d "name=在庫テスト" \
  -d "category=その他" \
  -d "price=1000" \
  -d "stock=99999" \
  -d "description=test" \
  http://127.0.0.1:5000/products/new)
if echo "$RESULT" | grep -q "登録しました"; then
    echo "  結果: 【脆弱性】上限を超える在庫数で登録成功"
elif echo "$RESULT" | grep -q "999個以下"; then
    echo "  結果: サーバー側検証が機能（適切）"
fi

# Test: 商品名の長さ制限
echo ""
echo "[TEST 14] 商品名の長さ制限バイパス"
LONG_NAME=$(python3 -c "print('A' * 500)")
RESULT=$(curl -s -b admin2_cookies.txt -d "name=$LONG_NAME" \
  -d "category=その他" \
  -d "price=1000" \
  -d "stock=10" \
  -d "description=test" \
  http://127.0.0.1:5000/products/new)
if echo "$RESULT" | grep -q "登録しました"; then
    echo "  結果: 【脆弱性】50文字を超える商品名で登録成功"
elif echo "$RESULT" | grep -q "50文字以下"; then
    echo "  結果: サーバー側検証が機能（適切）"
fi

# Test: セッションのタイムアウト確認
echo ""
echo "[TEST 15] セッションのタイムアウト設定"
echo "  注意: 短時間での確認は困難なため、設定の有無のみ確認"
# app.pyを確認（実際のファイルアクセスはできないため、推測）
echo "  仮説: Flaskのデフォルト設定では永続セッション（SESSION_PERMANENT）の設定次第"
echo "  推奨: PERMANENT_SESSION_LIFETIME を適切に設定すべき"

# Test: Content-Typeヘッダーの確認（JSONインジェクション対策）
echo ""
echo "[TEST 16] Content-Typeヘッダーの適切性"
CONTENT_TYPE=$(curl -s -I -b admin2_cookies.txt http://127.0.0.1:5000/products | grep -i "Content-Type")
echo "  $CONTENT_TYPE"
if echo "$CONTENT_TYPE" | grep -q "text/html"; then
    echo "  結果: HTMLとして適切に配信"
fi

# Test: ユーザー列挙攻撃
echo ""
echo "[TEST 17] ユーザー列挙攻撃の可能性"
RESULT_VALID=$(curl -s -d "username=admin" -d "password=wrong" http://127.0.0.1:5000/login)
RESULT_INVALID=$(curl -s -d "username=nonexistent" -d "password=wrong" http://127.0.0.1:5000/login)
ERROR_VALID=$(echo "$RESULT_VALID" | grep -o "ユーザー名またはパスワードが正しくありません" | head -1)
ERROR_INVALID=$(echo "$RESULT_INVALID" | grep -o "ユーザー名またはパスワードが正しくありません" | head -1)
if [ "$ERROR_VALID" == "$ERROR_INVALID" ]; then
    echo "  結果: 同じエラーメッセージ（適切）"
else
    echo "  結果: 【脆弱性】異なるエラーメッセージでユーザー存在を判別可能"
fi

# Test: レート制限（ブルートフォース対策）
echo ""
echo "[TEST 18] ブルートフォース攻撃対策（レート制限）"
echo "  連続10回のログイン試行..."
for i in {1..10}; do
    curl -s -d "username=admin" -d "password=wrong$i" http://127.0.0.1:5000/login > /dev/null
done
RESULT=$(curl -s -d "username=admin" -d "password=wrong11" http://127.0.0.1:5000/login)
if echo "$RESULT" | grep -q "試行回数\|制限\|ロック"; then
    echo "  結果: レート制限あり（適切）"
else
    echo "  結果: 【脆弱性】レート制限なし - ブルートフォース攻撃が可能"
fi

# Test: オープンリダイレクト
echo ""
echo "[TEST 19] オープンリダイレクト脆弱性"
RESULT=$(curl -s -i "http://127.0.0.1:5000/login?next=http://evil.com" | grep -i "Location:")
if echo "$RESULT" | grep -q "evil.com"; then
    echo "  結果: 【脆弱性】オープンリダイレクト可能"
else
    echo "  結果: オープンリダイレクト対策済み、または機能なし"
fi

# Test: HTTPメソッドの制限
echo ""
echo "[TEST 20] 不適切なHTTPメソッドの使用"
echo "  GETメソッドで削除を試行..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b admin2_cookies.txt -X GET http://127.0.0.1:5000/products/3/delete)
if [ "$STATUS" == "405" ]; then
    echo "  結果: Method Not Allowed（適切）"
elif [ "$STATUS" == "200" ] || [ "$STATUS" == "302" ]; then
    echo "  結果: 【脆弱性】GETメソッドで削除可能（CSRF攻撃リスク増大）"
else
    echo "  結果: ステータス $STATUS"
fi

echo ""
echo "=== 追加セキュリティテスト完了 ==="
