(() => {
  if (!/Android/i.test(navigator.userAgent) || window.matchMedia('(display-mode: standalone)').matches) return;
  let pending = null;
  const panel = document.createElement('div');
  panel.setAttribute('role', 'region');
  panel.setAttribute('aria-label', 'Uygulama kurulumu');
  Object.assign(panel.style, {position:'fixed',right:'12px',bottom:'max(12px, env(safe-area-inset-bottom))',zIndex:'10000',maxWidth:'calc(100vw - 24px)',background:'#fff',border:'1px solid #c7d2fe',borderRadius:'12px',padding:'8px',boxShadow:'0 4px 16px #0002',fontFamily:'Arial,sans-serif',fontSize:'13px'});
  const install = document.createElement('button');
  install.type = 'button';
  install.textContent = 'Uygulamayı Yükle';
  Object.assign(install.style,{background:'#1a237e',color:'#fff',border:'none',borderRadius:'8px',padding:'10px 14px',fontWeight:'bold',cursor:'pointer'});
  const close = document.createElement('button');
  close.type = 'button';close.textContent = '×';close.setAttribute('aria-label','Kurulum önerisini kapat');
  Object.assign(close.style,{background:'transparent',border:'none',padding:'8px',fontSize:'20px',cursor:'pointer'});
  const help = document.createElement('p');
  help.textContent = 'Tarayıcı menüsünden “Uygulamayı yükle” veya “Ana ekrana ekle” seçeneğini kullanabilirsin.';
  Object.assign(help.style,{display:'none',margin:'8px 4px 4px',maxWidth:'260px',lineHeight:'1.4'});
  panel.append(install,close,help);
  document.body.append(panel);
  close.addEventListener('click',() => panel.remove());
  install.addEventListener('click',async () => {
    if (!pending) { help.style.display = help.style.display === 'none' ? 'block' : 'none'; return; }
    const request = pending;pending = null;
    try {
      await request.prompt();
      const choice = await request.userChoice;
      if (choice.outcome === 'accepted') panel.remove();
    } catch (_) { help.style.display='block'; }
  });
  window.addEventListener('beforeinstallprompt',event => {
    event.preventDefault();pending = event;
  });
  window.addEventListener('appinstalled',() => panel.remove());
})();
