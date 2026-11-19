(function(){
  var b=(window.AIO&&window.AIO.biz)||{};
  var nice={legalName:'registered business name',email:'email address',address:'shop address',hours:'opening hours'};
  document.querySelectorAll('[data-biz]').forEach(function(el){
    var k=el.dataset.biz,v=b[k];
    if(k==='freeDeliveryOver'&&v)v='KES '+Number(v).toLocaleString('en-KE');
    if(v===undefined||v===null||v===''){
      if(k==='legalName'&&b.name){el.textContent=b.name;return}
      el.textContent='['+(nice[k]||k)+' to be added]';el.className='todo';
    }else el.textContent=v;
  });
  var d=document.getElementById('draftBanner');
  if(d&&b.draft===false)d.remove();
  var y=document.getElementById('yr');if(y)y.textContent=new Date().getFullYear();
})();
