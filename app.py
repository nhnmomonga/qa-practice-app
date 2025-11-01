"""
QA Practice App - テスト練習用Webアプリケーション
商品在庫管理システム
"""

from flask import Flask, render_template, request, redirect, url_for, session, flash
import sqlite3
import os
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'qa-practice-app-secret-key-for-testing'

# データベースファイルのパス
DATABASE = 'database.db'

# 固定ユーザーアカウント
USERS = {
    'admin': {'password': 'admin_password', 'role': 'admin'},
    'user': {'password': 'user_password', 'role': 'user'}
}

def get_db_connection():
    """データベース接続を取得"""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """データベースを初期化"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 商品テーブルの作成
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            price INTEGER NOT NULL,
            stock INTEGER NOT NULL,
            description TEXT,
            status TEXT NOT NULL DEFAULT '準備中',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # サンプルデータの挿入
    cursor.execute('SELECT COUNT(*) FROM products')
    if cursor.fetchone()[0] == 0:
        sample_products = [
            ('Python入門書', '書籍', 2980, 15, 'プログラミング初心者向けの入門書です。', '公開中'),
            ('ノートパソコン', '家電', 89800, 5, '高性能なノートパソコンです。', '公開中'),
            ('有機野菜セット', '食品', 1980, 0, '新鮮な有機野菜の詰め合わせです。', '公開中'),
            ('ワイヤレスマウス', '家電', 2480, 8, 'Bluetooth対応のワイヤレスマウスです。', '公開中'),
            ('コーヒー豆', '食品', 1280, 25, '厳選されたコーヒー豆です。', '公開中'),
            ('ビジネス書', '書籍', 1800, 3, 'ビジネススキル向上の本です。', '準備中'),
            ('USB充電器', 'その他', 980, 100, 'USB Type-C対応の充電器です。', '公開中'),
            ('お茶セット', '食品', 3200, 12, '高級お茶の詰め合わせです。', '非公開'),
        ]
        cursor.executemany(
            'INSERT INTO products (name, category, price, stock, description, status) VALUES (?, ?, ?, ?, ?, ?)',
            sample_products
        )
    
    conn.commit()
    conn.close()

@app.route('/')
def index():
    """トップページ（ログインしていない場合はログインページへリダイレクト）"""
    if 'username' not in session:
        return redirect(url_for('login'))
    return redirect(url_for('products_list'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """ログインページ"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        # ユーザー認証
        if username in USERS and USERS[username]['password'] == password:
            session['username'] = username
            session['role'] = USERS[username]['role']
            flash(f'{username}さん、ログインしました。', 'success')
            return redirect(url_for('products_list'))
        else:
            flash('ユーザー名またはパスワードが正しくありません。', 'error')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """ログアウト"""
    username = session.get('username')
    session.clear()
    flash(f'{username}さん、ログアウトしました。', 'info')
    return redirect(url_for('login'))

@app.route('/products')
def products_list():
    """商品一覧ページ"""
    if 'username' not in session:
        return redirect(url_for('login'))
    
    # 検索条件の取得
    keyword = request.args.get('keyword', '')
    category = request.args.get('category', '')
    price_min = request.args.get('price_min', '')
    price_max = request.args.get('price_max', '')
    
    # 【意図的な不具合】テスト練習用: キーワードに「バグ票」が含まれている場合は500エラー
    # これは「エラー推測テスト」の練習のための仕様です
    if 'バグ票' in keyword:
        from werkzeug.exceptions import InternalServerError
        raise InternalServerError('意図的なエラー: キーワードに「バグ票」が含まれています')
    
    conn = get_db_connection()
    
    # クエリの構築
    query = 'SELECT * FROM products WHERE 1=1'
    params = []
    
    if keyword:
        query += ' AND name LIKE ?'
        params.append(f'%{keyword}%')
    
    if category:
        query += ' AND category = ?'
        params.append(category)
    
    if price_min:
        query += ' AND price >= ?'
        params.append(int(price_min))
    
    if price_max:
        query += ' AND price <= ?'
        params.append(int(price_max))
    
    query += ' ORDER BY id DESC'
    
    products = conn.execute(query, params).fetchall()
    conn.close()
    
    return render_template('products_list.html', products=products)

@app.route('/products/new', methods=['GET', 'POST'])
def product_new():
    """商品登録ページ"""
    if 'username' not in session:
        return redirect(url_for('login'))
    
    # 権限チェック: adminのみ登録可能
    if session.get('role') != 'admin':
        flash('商品の登録権限がありません。', 'error')
        return redirect(url_for('products_list'))
    
    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        category = request.form.get('category')
        price = request.form.get('price')
        stock = request.form.get('stock')
        description = request.form.get('description', '')
        status = '準備中'  # 新規登録時は常に「準備中」
        
        # バリデーション
        errors = []
        
        # 商品名: 1文字以上、50文字以下
        if not name:
            errors.append('商品名は必須です。')
        elif len(name) < 1 or len(name) > 50:
            errors.append('商品名は1文字以上、50文字以下で入力してください。')
        
        # 価格: 0円以上、1,000,000円以下
        try:
            price = int(price)
            if price < 0 or price > 1000000:
                errors.append('価格は0円以上、1,000,000円以下で入力してください。')
        except (ValueError, TypeError):
            errors.append('価格は数値で入力してください。')
            price = None
        
        # 在庫数: 0個以上、999個以下
        try:
            stock = int(stock)
            if stock < 0 or stock > 999:
                errors.append('在庫数は0個以上、999個以下で入力してください。')
        except (ValueError, TypeError):
            errors.append('在庫数は整数で入力してください。')
            stock = None
        
        if errors:
            for error in errors:
                flash(error, 'error')
            return render_template('product_form.html', 
                                 name=name, category=category, 
                                 price=request.form.get('price'), 
                                 stock=request.form.get('stock'),
                                 description=description,
                                 status=status,
                                 is_new=True)
        
        # 【意図的な脆弱性】テスト練習用: XSS対策なし
        # 商品説明フィールドにHTMLタグ（<script>など）を入力すると、
        # エスケープせずに保存されます。これは「セキュリティテスト」の練習のための仕様です。
        # 警告: 本番環境では絶対に使用しないでください
        conn = get_db_connection()
        conn.execute(
            'INSERT INTO products (name, category, price, stock, description, status) VALUES (?, ?, ?, ?, ?, ?)',
            (name, category, price, stock, description, status)
        )
        conn.commit()
        conn.close()
        
        flash('商品を登録しました。', 'success')
        return redirect(url_for('products_list'))
    
    return render_template('product_form.html', is_new=True)

@app.route('/products/<int:product_id>/edit', methods=['GET', 'POST'])
def product_edit(product_id):
    """商品編集ページ"""
    if 'username' not in session:
        return redirect(url_for('login'))
    
    # adminとuserは編集可能
    if session.get('role') not in ['admin', 'user']:
        flash('商品の編集権限がありません。', 'error')
        return redirect(url_for('products_list'))
    
    conn = get_db_connection()
    product = conn.execute('SELECT * FROM products WHERE id = ?', (product_id,)).fetchone()
    
    if product is None:
        conn.close()
        flash('商品が見つかりません。', 'error')
        return redirect(url_for('products_list'))
    
    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        category = request.form.get('category')
        price = request.form.get('price')
        stock = request.form.get('stock')
        description = request.form.get('description', '')
        new_status = request.form.get('status')
        current_status = product['status']
        
        # バリデーション
        errors = []
        
        # 商品名: 1文字以上、50文字以下
        if not name:
            errors.append('商品名は必須です。')
        elif len(name) < 1 or len(name) > 50:
            errors.append('商品名は1文字以上、50文字以下で入力してください。')
        
        # 価格: 0円以上、1,000,000円以下
        try:
            price = int(price)
            if price < 0 or price > 1000000:
                errors.append('価格は0円以上、1,000,000円以下で入力してください。')
        except (ValueError, TypeError):
            errors.append('価格は数値で入力してください。')
            price = None
        
        # 在庫数: 0個以上、999個以下
        try:
            stock = int(stock)
            if stock < 0 or stock > 999:
                errors.append('在庫数は0個以上、999個以下で入力してください。')
        except (ValueError, TypeError):
            errors.append('在庫数は整数で入力してください。')
            stock = None
        
        # ステータス遷移のバリデーション
        valid_transition = False
        if current_status == '準備中' and new_status in ['公開中', '非公開']:
            valid_transition = True
        elif current_status == '公開中' and new_status == '非公開':
            valid_transition = True
        elif current_status == '非公開' and new_status == '公開中':
            valid_transition = True
        elif current_status == new_status:
            valid_transition = True
        
        if not valid_transition:
            errors.append(f'ステータスを「{current_status}」から「{new_status}」へ変更することはできません。')
        
        if errors:
            for error in errors:
                flash(error, 'error')
            conn.close()
            return render_template('product_form.html',
                                 product=product,
                                 name=name, category=category,
                                 price=request.form.get('price'),
                                 stock=request.form.get('stock'),
                                 description=description,
                                 status=new_status,
                                 is_new=False)
        
        # 商品の更新
        conn.execute(
            'UPDATE products SET name=?, category=?, price=?, stock=?, description=?, status=?, updated_at=? WHERE id=?',
            (name, category, price, stock, description, new_status, datetime.now(), product_id)
        )
        conn.commit()
        conn.close()
        
        flash('商品を更新しました。', 'success')
        return redirect(url_for('products_list'))
    
    conn.close()
    return render_template('product_form.html', product=product, is_new=False)

@app.route('/products/<int:product_id>/delete', methods=['POST'])
def product_delete(product_id):
    """
    商品削除
    
    【意図的な不具合】テスト練習用: 確認ダイアログなし
    フロントエンドに確認ダイアログ（JavaScript confirm）が実装されていないため、
    削除ボタンを押すと即座に商品が削除されます。
    これは「ユーザビリティテスト」や「エラー推測テスト」の練習のための仕様です。
    警告: 本番環境ではユーザー確認を必ず実装してください
    """
    if 'username' not in session:
        return redirect(url_for('login'))
    
    # 権限チェック: adminのみ削除可能
    if session.get('role') != 'admin':
        flash('商品の削除権限がありません。', 'error')
        return redirect(url_for('products_list'))
    
    conn = get_db_connection()
    conn.execute('DELETE FROM products WHERE id = ?', (product_id,))
    conn.commit()
    conn.close()
    
    flash('商品を削除しました。', 'success')
    return redirect(url_for('products_list'))

@app.template_filter('stock_status')
def stock_status_filter(stock):
    """在庫数に応じたステータステキストを返す"""
    if stock == 0:
        return '在庫切れ'
    elif 1 <= stock <= 10:
        return '残りわずか'
    else:
        return '在庫あり'

@app.template_filter('stock_color')
def stock_color_filter(stock):
    """在庫数に応じた背景色のCSSクラスを返す"""
    if stock == 0:
        return 'bg-red'
    elif 1 <= stock <= 10:
        return 'bg-yellow'
    else:
        return ''

@app.template_filter('number_format')
def number_format_filter(value):
    """数値を3桁カンマ区切りでフォーマット"""
    try:
        return '{:,}'.format(int(value))
    except (ValueError, TypeError):
        return value

if __name__ == '__main__':
    # データベースの初期化
    if not os.path.exists(DATABASE):
        init_db()
        print('データベースを初期化しました。')
    
    print('QA Practice App を起動します...')
    print('ブラウザで http://127.0.0.1:5000 にアクセスしてください。')
    print('ログイン情報:')
    print('  管理者 - ID: admin, PW: admin_password')
    print('  ユーザー - ID: user, PW: user_password')
    
    app.run(debug=True, host='0.0.0.0', port=5000)
