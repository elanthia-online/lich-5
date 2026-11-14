const style = selector => getComputedStyle(document.querySelector(selector));
const height = selector => document.querySelector(selector).getBoundingClientRect().height;
const measurements = {
  headerHeight: height('#plain th'), rowHeight: height('#plain tbody tr'),
  headerColor: style('#plain th').color, normalColor: style('#plain tbody tr:nth-child(2)').color,
  gridNoneBorder: style('#plain td').borderBottomWidth, rowPadding: style('#plain td').paddingLeft,
  selectedColor: style('#plain tbody tr').color, selectedBackground: style('#plain tbody tr').backgroundColor,
  gridBorder: style('#grid td').borderRightWidth, ordinaryHeaderColor: style('#ordinary th').color,
  textEditorHeight: height('#editors input'), selectEditorHeight: height('#editors select'), editorRowHeight: height('#editors tbody tr'),
  headerBackground: style('#plain th').backgroundColor, headerTopBorder: style('#plain th').borderTopWidth,
  lastHeaderRightBorder: style('#plain th:last-child').borderRightWidth,
  buttonColor: style('#default-button').color, buttonGradient: style('#default-button').backgroundImage,
  buttonRadius: style('#default-button').borderRadius, buttonShadow: style('#default-button').boxShadow,
  disabledColor: style('#disabled-button').color, primaryColor: style('#primary-button').color
};
const pass = measurements.headerHeight === 25 && measurements.rowHeight === 21 &&
  measurements.headerColor === 'rgb(151, 154, 155)' && measurements.normalColor === 'rgb(0, 0, 0)' &&
  measurements.gridNoneBorder === '0px' && measurements.rowPadding === '4px' &&
  measurements.selectedColor === 'rgb(255, 255, 255)' && measurements.selectedBackground === 'rgb(53, 132, 228)' &&
  measurements.gridBorder === '1px' && measurements.ordinaryHeaderColor !== measurements.headerColor &&
  measurements.textEditorHeight === 21 && measurements.selectEditorHeight === 34 && height('#editors tbody tr') === 21 &&
  measurements.headerBackground === 'rgb(255, 255, 255)' && measurements.headerTopBorder === '0px' &&
  measurements.lastHeaderRightBorder === '0px' && measurements.buttonColor === 'rgb(46, 52, 54)' &&
  measurements.buttonGradient === 'linear-gradient(to top, rgb(237, 235, 233) 2px, rgb(246, 245, 244))' &&
  measurements.buttonRadius === '5px' && measurements.buttonShadow !== 'none' &&
  measurements.disabledColor === 'rgb(146, 149, 149)' && measurements.primaryColor === 'rgb(255, 255, 255)';
document.getElementById('result').textContent = (pass ? 'PASS' : 'FAIL') + '\n' + JSON.stringify(measurements, null, 2);
