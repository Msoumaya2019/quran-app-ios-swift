import Foundation

enum TajweedMushafHTML {
    // Same QCF proportions as Quran.com's fixed-line scale (64.5 / 3.7 / 6.1).
    // Only the entire canvas is scaled. The 15 rows never wrap or use Dynamic Type.
    static let width = 1000.0
    static let height = 1360.0
    static func document(_ page: TajweedMushafPage) throws -> String {
        let json = String(decoding: try JSONEncoder().encode(page), as: UTF8.self)
        return #"""
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; font-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'">
        <style>
        @font-face{font-family:Page;src:url('page.woff2') format('woff2');font-display:block}
        @font-face{font-family:Basmala;src:url('basmala.woff2') format('woff2');font-display:block}
        @font-face{font-family:Surahs;src:url('surahs.woff2') format('woff2');font-display:block}
        @font-palette-values --Light{font-family:Page;base-palette:0}
        *{box-sizing:border-box;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}
        html,body{margin:0;width:100%;height:100%;overflow:hidden;background:white;-webkit-text-size-adjust:none}
        body{display:flex;align-items:center;justify-content:center}
        #canvas{width:1000px;height:1360px;position:relative;transform-origin:top left;visibility:hidden}
        .line{position:absolute;left:50px;width:900px;height:85.12px;display:flex;direction:rtl;align-items:center;justify-content:space-between;font:51.628px Page;font-palette:--Light;white-space:nowrap;flex-wrap:nowrap;line-height:85.12px}
        .word{display:inline-block;flex:none;white-space:pre;line-height:85.12px}
        .center{justify-content:center;gap:12px}
        .title{font-family:Surahs;justify-content:center;font-size:48px}
        .basmala{font-family:Basmala;justify-content:center;font-size:47px}
        #footer{position:absolute;top:1320px;width:100%;text-align:center;font:18px system-ui;color:#555}
        </style></head><body><div id="fit"><div id="canvas"></div></div><script>
        const page=\#(json), canvas=document.getElementById('canvas');
        const centered={255:[2],528:[9],534:[6],545:[6],586:[1],593:[2],594:[5],600:[10],602:[5,15],603:[10,15],604:[4,9,14,15]};
        const post=(kind,value)=>window.webkit.messageHandlers.mushaf.postMessage({kind,page:page.number,value});
        const lines=new Map();
        for(let i=1;i<=15;i++){let row=document.createElement('div');row.className='line';row.style.top=(20+(i-1)*85.12)+'px';row.dataset.line=i;canvas.appendChild(row);lines.set(i,row);}
        for(const word of page.words){const row=lines.get(word.line);const el=document.createElement('span');el.className='word';el.dataset.verseKey=word.verseKey;el.dataset.line=word.line;el.textContent=word.glyph;row.appendChild(el);}
        for(const [number,row] of lines){if(page.number<=2||(centered[page.number]||[]).includes(number))row.classList.add('center');}
        for(const word of page.words){if(word.position!==1||!word.verseKey.endsWith(':1'))continue;
          const chapter=Number(word.verseKey.split(':')[0]);const titleLine=chapter===1||chapter===9?word.line-1:word.line-2;
          const title=lines.get(titleLine);if(title&&title.children.length===0){title.className='line title';title.textContent=String(chapter).padStart(3,'0');}
          const basmala=lines.get(word.line-1);if(chapter!==1&&chapter!==9&&basmala&&basmala.children.length===0){basmala.className='line basmala';basmala.textContent='ﱁ ﱂ ﱃ ﱄ';}
        }
        let footer=document.createElement('div');footer.id='footer';footer.textContent=page.number;canvas.appendChild(footer);
        function fit(){const scale=Math.min(innerWidth/1000,innerHeight/1360);document.getElementById('fit').style.cssText=`width:${1000*scale}px;height:${1360*scale}px`;canvas.style.transform=`scale(${scale})`;}
        window.selectAt=function(x,y){const el=document.elementFromPoint(x,y)?.closest('[data-verse-key]');if(el)post('verse',el.dataset.verseKey);};
        window.addEventListener('resize',fit);document.addEventListener('contextmenu',event=>event.preventDefault());
        Promise.all([document.fonts.load('51.628px Page'),document.fonts.load('47px Basmala'),document.fonts.load('48px Surahs')]).then(()=>{
          if(!document.fonts.check('51.628px Page')||!document.fonts.check('48px Surahs'))throw Error('font unavailable');
          fit();canvas.style.visibility='visible';requestAnimationFrame(()=>{
            const c=canvas.getBoundingClientRect();const regions=[...canvas.querySelectorAll('.word')].map(el=>{const r=el.getBoundingClientRect();return {key:el.dataset.verseKey,line:Number(el.dataset.line),x:(r.x-c.x)/c.width,y:(r.y-c.y)/c.height,width:r.width/c.width,height:r.height/c.height};});post('ready',regions);
          });
        }).catch(error=>post('error',String(error)));
        </script></body></html>
        """#
    }
}
