// Serialized by Playwright into the fixture browser; keep this callback self-contained.
// A posted task runs after this frame's callbacks, including scroll restoration.
// If a later render retires the captured scroller, sample its replacement again.
function sampleCanvasScroll(property) {
  return new Promise(resolve => {
    const sample = () => requestAnimationFrame(() => {
      const element = document.querySelector('.webui-scroll');
      const channel = new MessageChannel();
      channel.port1.onmessage = () => {
        channel.port1.close();
        channel.port2.close();
        if (element?.isConnected) resolve(element[property]);
        else sample();
      };
      channel.port2.postMessage(null);
    });
    sample();
  });
}

module.exports = { sampleCanvasScroll };
