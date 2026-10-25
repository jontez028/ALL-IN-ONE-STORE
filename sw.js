/* All In One Store service worker: pages load fresh when online, and the last copy opens when offline. */
var V='aio-v2';
self.addEventListener('install',function(e){self.skipWaiting();e.waitUntil(caches.open(V).then(function(c){return c.addAll(['./','index.html','manifest.webmanifest','icons/icon-192.png'])}).catch(function(){}))});
self.addEventListener('activate',function(e){e.waitUntil(caches.keys().then(function(k){return Promise.all(k.filter(function(n){return n!==V}).map(function(n){return caches.delete(n)}))}).then(function(){return self.clients.claim()}))});
self.addEventListener('fetch',function(e){
  var r=e.request,u=new URL(r.url);
  if(r.method!=='GET'||u.hostname.endsWith('supabase.co'))return;
  e.respondWith(fetch(r).then(function(res){
    if(res&&res.ok&&(u.origin===location.origin||u.hostname==='cdn.jsdelivr.net')){var cp=res.clone();caches.open(V).then(function(c){c.put(r,cp)})}
    return res;
  }).catch(function(){return caches.match(r).then(function(m){return m||(r.mode==='navigate'?caches.match('index.html'):Response.error())})}));
});
