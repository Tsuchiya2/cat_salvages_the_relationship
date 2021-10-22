window.addEventListener('scroll', () => {                                         // 'スクロール'(イベント)が発生するとアロー関数以下が動きます。
  let targets = document.querySelectorAll('.fade-in');                            // 'fade-in'クラスを集計。
  for (let i = 0; i < targets.length; i++){                                       // iに0を代入し、'targets'の数を下回れば、iの値を増やします。
    const selectorPlace = targets[i].getBoundingClientRect().top;                 // 個々の'targets'までの距離
    const scrollAmount = window.scrollY || document.documentElement.scrollTop;    // 現在のスクロール位置
    const referencePoint = selectorPlace + scrollAmount;                          // 基準点
    const windowHeight = window.innerHeight;                                      // ユーザーが使用しているブラウザの高さ
    if (scrollAmount > referencePoint - windowHeight + 275) {
      targets[i].classList.add('scroll-in');
    }
  }
});

// https://developer.mozilla.org/ja/docs/Web/JavaScript/Reference/Statements/for
// https://developer.mozilla.org/ja/docs/Web/API/Element/getBoundingClientRect
// https://developer.mozilla.org/ja/docs/Web/API/Window/scrollY
// https://developer.mozilla.org/ja/docs/Web/API/Element/scrollTop
// https://flex-box.net/js-scrollin/
