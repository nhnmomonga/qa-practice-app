#!/bin/bash
echo "=== CSRF脆弱性の詳細テスト ==="

# ログインフォームを取得
echo "[1] ログインフォームのCSRFトークン確認"
curl -s http://127.0.0.1:5000/login > login_form.html
if grep -q "csrf" login_form.html; then
    echo "  結果: CSRFトークンフィールドあり"
    grep csrf login_form.html
else
    echo "  結果: 【脆弱性】CSRFトークンフィールドなし"
fi

# 商品削除フォームを取得
echo ""
echo "[2] 商品削除フォームのCSRFトークン確認"
curl -s -c admin_cookies.txt -d "username=admin" -d "password=admin_password" http://127.0.0.1:5000/login > /dev/null
curl -s -b admin_cookies.txt http://127.0.0.1:5000/products > products_page.html
if grep -q "csrf" products_page.html; then
    echo "  結果: CSRFトークンフィールドあり"
    grep csrf products_page.html | head -3
else
    echo "  結果: 【脆弱性】CSRFトークンフィールドなし"
fi

# CSRF攻撃のシミュレーション
echo ""
echo "[3] CSRF攻撃のシミュレーション（外部サイトからの削除リクエスト）"
echo "  意図: 別セッションから商品削除を試行（CSRFトークンなし）"
# 新しいセッションで削除リクエストを送信
curl -s -b admin_cookies.txt -X POST http://127.0.0.1:5000/products/2/delete > delete_result.html
if grep -q "削除しました" delete_result.html; then
    echo "  結果: 【重大な脆弱性】CSRFトークンなしで削除成功！"
    echo "  影響: 攻撃者が作成した悪意のあるページから、ログイン中のユーザーに"
    echo "        意図しない操作（商品削除など）を実行させることが可能"
elif grep -q "CSRF" delete_result.html; then
    echo "  結果: CSRF保護により削除拒否"
else
    echo "  結果: 削除実行（CSRFトークン検証の有無は不明）"
fi

# 商品登録フォームの確認
echo ""
echo "[4] 商品登録フォームのCSRFトークン確認"
curl -s -b admin_cookies.txt http://127.0.0.1:5000/products/new > new_product_form.html
if grep -q "csrf" new_product_form.html; then
    echo "  結果: CSRFトークンフィールドあり"
else
    echo "  結果: 【脆弱性】CSRFトークンフィールドなし"
fi

echo ""
echo "=== CSRF脆弱性テスト完了 ==="
