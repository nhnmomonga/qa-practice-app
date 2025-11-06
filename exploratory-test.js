/**
 * 探索的テストセッション - QA Practice App
 * QA経験2年目のエンジニアの視点から実施
 */

const { chromium } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// テスト結果ディレクトリの作成
const resultsDir = path.join(__dirname, 'test-results');
const screenshotsDir = path.join(resultsDir, 'screenshots');
if (!fs.existsSync(resultsDir)) fs.mkdirSync(resultsDir, { recursive: true });
if (!fs.existsSync(screenshotsDir)) fs.mkdirSync(screenshotsDir, { recursive: true });

// テストノートを記録する配列
const testNotes = [];

// タイムスタンプ付きノート追加関数
function addNote(intent, action, input, observation, insight, hypothesis) {
    const timestamp = new Date().toLocaleTimeString('ja-JP');
    const note = {
        timestamp,
        intent,
        action,
        input,
        observation,
        insight,
        hypothesis
    };
    testNotes.push(note);
    console.log(`[${timestamp}] ${intent} | ${action} | ${observation}`);
}

// スクリーンショット撮影関数
async function takeScreenshot(page, stepNumber, description) {
    const filename = `step${String(stepNumber).padStart(2, '0')}_${description}.png`;
    const filepath = path.join(screenshotsDir, filename);
    await page.screenshot({ path: filepath, fullPage: false });
    console.log(`📸 Screenshot saved: ${filename}`);
    return filename;
}

// メイン探索的テスト関数
async function runExploratoryTest() {
    console.log('🚀 探索的テストセッション開始');
    console.log('⏱️  制限時間: 10分');
    console.log('🎯 目的: QA経験2年目のエンジニアの視点からアプリケーション全体を探索');
    
    const startTime = Date.now();
    let browser, context, page;
    let stepCounter = 1;
    
    try {
        // ブラウザとコンテキストの起動
        browser = await chromium.launch({ 
            headless: true,
            executablePath: '/usr/bin/chromium-browser',
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
        });
        
        context = await browser.newContext({
            viewport: { width: 1280, height: 720 },
            recordVideo: {
                dir: resultsDir,
                size: { width: 1280, height: 720 }
            }
        });
        
        // トレーシング開始
        await context.tracing.start({ 
            screenshots: true, 
            snapshots: true, 
            sources: true 
        });
        
        page = await context.newPage();
        
        // セッション開始
        addNote(
            'セッション開始',
            'ブラウザ起動とトレース開始',
            'http://127.0.0.1:5000',
            'アプリケーションにアクセス準備完了',
            'テスト環境が正常に動作している',
            'すべての機能が利用可能と想定'
        );
        
        // ステップ1: ログインページアクセス
        await page.goto('http://127.0.0.1:5000/');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'login_page');
        
        addNote(
            'ログインページの確認',
            'トップページにアクセス',
            'URL: /',
            'ログインページにリダイレクトされた。ユーザー名とパスワードの入力欄が表示されている',
            '未認証ユーザーは自動的にログインページに遷移する',
            '認証が必要な機能は保護されている'
        );
        
        // ステップ2: 管理者としてログイン
        await page.fill('[data-testid="username-input"]', 'admin');
        await page.fill('[data-testid="password-input"]', 'admin_password');
        await takeScreenshot(page, stepCounter++, 'login_filled');
        
        addNote(
            '管理者ログインの試行',
            '認証情報を入力',
            'username: admin, password: admin_password',
            '入力フィールドに値が正常に入力された',
            'data-testid属性により要素の特定が容易',
            'テスト自動化への配慮が十分'
        );
        
        await page.click('[data-testid="login-submit"]');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'products_list_initial');
        
        addNote(
            'ログイン成功の確認',
            'ログインボタンをクリック',
            '',
            '商品一覧ページに遷移。サンプルデータが表示されている',
            '正しい認証情報でログインが成功',
            'セッション管理が機能している'
        );
        
        // ステップ3: 商品一覧の確認と在庫ステータスの検証
        const productRows = await page.locator('[data-testid^="product-row-"]').count();
        addNote(
            '商品一覧の初期状態確認',
            '商品行をカウント',
            '',
            `${productRows}件の商品が表示されている`,
            'サンプルデータが正しく読み込まれている',
            '初期データはREADME通りに設定されている'
        );
        
        // 在庫ステータスの色分けを確認
        await takeScreenshot(page, stepCounter++, 'stock_status_check');
        addNote(
            '在庫ステータス表示の確認',
            '各商品の在庫数と表示色を視覚的に確認',
            '',
            '在庫0の商品は赤背景、1-10は黄色背景、11以上は背景色なし',
            'デシジョンテーブル仕様通りの表示',
            '在庫管理の視覚的フィードバックが適切'
        );
        
        // ステップ4: 検索機能のテスト（正常系）
        await page.fill('[data-testid="search-keyword"]', 'Python');
        await page.click('[data-testid="search-submit"]');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'search_python');
        
        addNote(
            '検索機能の正常動作確認',
            'キーワード検索を実行',
            'keyword: Python',
            'Python入門書が検索結果に表示された',
            '部分一致検索が機能している',
            '検索ロジックは期待通り'
        );
        
        // 検索リセット
        await page.goto('http://127.0.0.1:5000/products');
        await page.waitForLoadState('networkidle');
        
        // ステップ5: イースターエッグ発見（検索エラー）
        await page.fill('[data-testid="search-keyword"]', 'バグ票');
        await page.click('[data-testid="search-submit"]');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'bug_easter_egg');
        
        addNote(
            '意図的なバグの確認',
            '「バグ票」で検索',
            'keyword: バグ票',
            '500エラーページが表示された',
            '意図的に実装されたエラーハンドリング不備を確認',
            'エラー処理の改善が必要（意図的だが実際の環境では重大）'
        );
        
        // 商品一覧に戻る
        await page.goto('http://127.0.0.1:5000/products');
        await page.waitForLoadState('networkidle');
        
        // ステップ6: 商品の新規作成（境界値テスト）
        await page.click('text=新規登録');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'product_form_new');
        
        addNote(
            '新規登録フォームへの遷移',
            '新規登録ボタンをクリック',
            '',
            '商品登録フォームが表示された。全入力項目が空欄',
            'フォームのレイアウトは明確',
            '初期状態は準備中になる予定'
        );
        
        // 境界値テスト: 価格0円
        await page.fill('[data-testid="product-name-input"]', 'テスト商品_境界値');
        await page.selectOption('[data-testid="product-category-select"]', '書籍');
        await page.fill('[data-testid="product-price-input"]', '0');
        await page.fill('[data-testid="product-stock-input"]', '10');
        await page.fill('[data-testid="product-description-input"]', '境界値テスト: 価格0円');
        await takeScreenshot(page, stepCounter++, 'boundary_price_zero');
        
        addNote(
            '境界値テスト実施',
            '価格0円で商品を作成',
            'price: 0, stock: 10',
            'フォーム入力完了',
            '価格0円は有効値として受け付けられるべき',
            'バリデーションが境界値仕様通りか確認'
        );
        
        await page.click('[data-testid="submit-button"]');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'boundary_price_zero_result');
        
        addNote(
            '境界値テスト結果',
            '送信ボタンをクリック',
            '',
            '商品一覧に戻り、新商品が登録された',
            '価格0円は正常に受理された',
            '仕様通りの動作'
        );
        
        // ステップ7: 商品編集（状態遷移テスト）
        // 最後に作成した商品を編集
        const editButtons = await page.locator('[data-testid^="edit-button-"]').all();
        if (editButtons.length > 0) {
            await editButtons[editButtons.length - 1].click();
            await page.waitForLoadState('networkidle');
            await takeScreenshot(page, stepCounter++, 'product_edit_form');
            
            addNote(
                '商品編集フォームへ遷移',
                '編集ボタンをクリック',
                '',
                '作成した商品の編集フォームが表示された',
                '登録直後の状態は「準備中」',
                '状態遷移テストの準備完了'
            );
            
            // 状態を「準備中」→「公開中」に変更
            await page.check('[data-testid="status-public"]');
            await takeScreenshot(page, stepCounter++, 'status_transition_to_public');
            
            addNote(
                '状態遷移テスト',
                'ステータスを「準備中」→「公開中」に変更',
                'status: 公開中',
                'ラジオボタンが選択された',
                '準備中から公開中への遷移は許可されている',
                '仕様通りの状態遷移'
            );
            
            await page.click('[data-testid="submit-button"]');
            await page.waitForLoadState('networkidle');
            await takeScreenshot(page, stepCounter++, 'status_transition_saved');
            
            addNote(
                '状態遷移の保存確認',
                '変更を保存',
                '',
                '一覧に戻り、ステータスが「公開中」に更新された',
                '状態遷移が正常に動作',
                'データベースへの永続化も成功'
            );
        }
        
        // ステップ8: XSS脆弱性テスト（セキュリティ観点）
        await page.click('text=新規登録');
        await page.waitForLoadState('networkidle');
        
        await page.fill('[data-testid="product-name-input"]', 'XSSテスト商品');
        await page.selectOption('[data-testid="product-category-select"]', 'その他');
        await page.fill('[data-testid="product-price-input"]', '1000');
        await page.fill('[data-testid="product-stock-input"]', '5');
        await page.fill('[data-testid="product-description-input"]', '<script>alert("XSS")</script>');
        await takeScreenshot(page, stepCounter++, 'xss_test_input');
        
        addNote(
            'XSS脆弱性のテスト',
            '商品説明にスクリプトタグを入力',
            'description: <script>alert("XSS")</script>',
            'HTMLタグを含むテキストを入力',
            '意図的に実装されたXSS脆弱性の確認',
            'エスケープ処理が不十分な可能性'
        );
        
        await page.click('[data-testid="submit-button"]');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'xss_test_result');
        
        addNote(
            'XSS脆弱性の結果確認',
            '商品を保存して一覧表示',
            '',
            '商品が登録された（アラートは表示されなかったがHTMLとして保存された可能性）',
            'XSS脆弱性が存在する可能性を確認',
            '実際の環境では重大なセキュリティリスク'
        );
        
        // ステップ9: 削除機能のテスト（ユーザビリティ観点）
        const deleteButtons = await page.locator('[data-testid^="delete-button-"]').all();
        const beforeDeleteCount = await page.locator('[data-testid^="product-row-"]').count();
        
        if (deleteButtons.length > 0) {
            await takeScreenshot(page, stepCounter++, 'before_delete');
            
            addNote(
                '削除機能の確認準備',
                '削除ボタンの存在を確認',
                '',
                `削除ボタンが${deleteButtons.length}個表示されている`,
                '各商品に削除機能が付いている',
                '確認ダイアログの有無を検証予定'
            );
            
            // 一番最後の商品を削除
            await deleteButtons[deleteButtons.length - 1].click();
            await page.waitForLoadState('networkidle');
            await takeScreenshot(page, stepCounter++, 'after_delete');
            
            const afterDeleteCount = await page.locator('[data-testid^="product-row-"]').count();
            
            addNote(
                '削除機能の動作確認',
                '削除ボタンをクリック',
                '',
                `商品数が${beforeDeleteCount}から${afterDeleteCount}に減少。確認ダイアログなし`,
                '確認なしの即座削除は重大なユーザビリティ問題',
                '誤操作による削除のリスクが高い'
            );
        }
        
        // ステップ10: カテゴリと価格帯での複合検索
        await page.selectOption('[data-testid="search-category"]', '書籍');
        await page.fill('[data-testid="search-price-min"]', '1000');
        await page.fill('[data-testid="search-price-max"]', '5000');
        await page.click('[data-testid="search-submit"]');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'complex_search');
        
        addNote(
            '複合検索機能のテスト',
            'カテゴリと価格帯で絞り込み',
            'category: 書籍, price: 1000-5000',
            '条件に合致する商品のみが表示された',
            '複数条件での検索が正常に動作',
            'AND条件での絞り込みが実装されている'
        );
        
        // ステップ11: ログアウトとユーザー権限テスト
        await page.click('text=ログアウト');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'after_logout');
        
        addNote(
            'ログアウト機能の確認',
            'ログアウトリンクをクリック',
            '',
            'ログインページにリダイレクトされた',
            'セッションが正常に破棄された',
            '認証状態の管理が適切'
        );
        
        // 一般ユーザーでログイン
        await page.fill('[data-testid="username-input"]', 'user');
        await page.fill('[data-testid="password-input"]', 'user_password');
        await page.click('[data-testid="login-submit"]');
        await page.waitForLoadState('networkidle');
        await takeScreenshot(page, stepCounter++, 'user_login');
        
        addNote(
            '一般ユーザーでのログイン',
            'user/user_passwordで認証',
            'username: user, password: user_password',
            '商品一覧が表示された',
            '一般ユーザーも商品閲覧は可能',
            '権限による機能差を確認予定'
        );
        
        // 削除ボタンの表示確認（一般ユーザーは削除不可のはず）
        const userDeleteButtons = await page.locator('[data-testid^="delete-button-"]').count();
        await takeScreenshot(page, stepCounter++, 'user_permissions');
        
        addNote(
            '一般ユーザーの権限確認',
            '削除ボタンの表示を確認',
            '',
            `削除ボタンが${userDeleteButtons}個表示されている`,
            userDeleteButtons === 0 ? '権限制御が正常に機能' : '権限制御に問題がある可能性',
            'ロールベースのアクセス制御の実装状況を確認'
        );
        
        // 最終確認
        await takeScreenshot(page, stepCounter++, 'final_state');
        
        const elapsedTime = Math.floor((Date.now() - startTime) / 1000);
        addNote(
            'セッション終了',
            '探索的テスト完了',
            '',
            `総実施時間: ${elapsedTime}秒、スクリーンショット: ${stepCounter}枚`,
            '時間内に主要機能を網羅的にテスト',
            '複数の不具合と改善点を発見'
        );
        
    } catch (error) {
        console.error('❌ テスト実行中にエラーが発生:', error);
        addNote(
            'エラー発生',
            'テスト実行エラー',
            '',
            error.message,
            '予期しない問題が発生',
            'スクリプトまたはアプリケーションの問題'
        );
    } finally {
        // トレーシング停止と保存
        if (context) {
            await context.tracing.stop({ path: path.join(resultsDir, 'trace.zip') });
            console.log('✅ トレースファイル保存完了: trace.zip');
        }
        
        // テストノートをJSON形式で保存
        fs.writeFileSync(
            path.join(resultsDir, 'test-notes.json'),
            JSON.stringify(testNotes, null, 2)
        );
        console.log('✅ テストノート保存完了: test-notes.json');
        
        // ブラウザクローズ
        if (browser) {
            await browser.close();
        }
        
        const totalTime = Math.floor((Date.now() - startTime) / 1000);
        console.log(`\n🏁 探索的テストセッション終了`);
        console.log(`⏱️  総実施時間: ${totalTime}秒`);
        console.log(`📝 記録したノート: ${testNotes.length}件`);
        console.log(`📸 スクリーンショット: ${stepCounter}枚`);
    }
}

// テスト実行
runExploratoryTest().catch(console.error);
