const device = document.getElementById('pager-device')
const lcd = document.getElementById('lcd-text')
const led = document.getElementById('led')
const bar = document.getElementById('bar')

let hideTimer = null
let tickTimer = null

function openPager(priority, text, duration) {
  device.classList.remove('hidden')
  lcd.textContent = (text || '').toUpperCase()
  if (priority === 'red') {
    led.style.background = '#ff3b3b'
    led.style.boxShadow = '0 0 10px rgba(255,59,59,0.9)'
  } else if (priority === 'yellow') {
    led.style.background = '#ffd84a'
    led.style.boxShadow = '0 0 10px rgba(255,216,74,0.9)'
  } else {
    led.style.background = '#27ff6a'
    led.style.boxShadow = '0 0 10px rgba(39,255,106,0.9)'
  }
  bar.style.width = '100%'
  if (hideTimer) clearTimeout(hideTimer)
  if (tickTimer) clearInterval(tickTimer)
  const dur = Math.max(1000, parseInt(duration || 20000, 10))
  const started = Date.now()
  tickTimer = setInterval(() => {
    const left = Math.max(0, dur - (Date.now() - started))
    const pct = left / dur * 100
    bar.style.width = pct + '%'
    if (left <= 0) clearInterval(tickTimer)
  }, 100)
  hideTimer = setTimeout(closePager, dur)
}

function closePager() {
  if (hideTimer) clearTimeout(hideTimer)
  if (tickTimer) clearInterval(tickTimer)
  device.classList.add('hidden')
  lcd.textContent = ''
  bar.style.width = '0%'
}

window.addEventListener('message', (e) => {
  if (e.data && e.data.action === 'showPager') {
    openPager(e.data.priority || 'green', e.data.message || '', e.data.duration || 20000)
  }
})

const recruit = document.getElementById('recruit')
const recruitForm = document.getElementById('recruit-form')
const btnSend = document.getElementById('recruit-send')
const btnCancel = document.getElementById('recruit-cancel')

function openRecruit(schema) {
  recruit.classList.remove('hidden')
  recruitForm.innerHTML = ''
  ;(schema || []).forEach(f => {
    const wrap = document.createElement('div')
    wrap.className = 'field'
    const lbl = document.createElement('label')
    lbl.textContent = f.label || f.key
    const el = (f.key === 'motivation') ? document.createElement('textarea') : document.createElement('input')
    el.name = f.key
    el.placeholder = f.label || f.key
    wrap.appendChild(lbl)
    wrap.appendChild(el)
    recruitForm.appendChild(wrap)
  })
}

function closeRecruit() {
  recruit.classList.add('hidden')
  recruitForm.innerHTML = ''
}

btnSend.addEventListener('click', () => {
  const data = {}
  const els = recruitForm.querySelectorAll('input,textarea')
  els.forEach(e => data[e.name] = e.value || '')
  fetch(`https://${GetParentResourceName()}/recruit:send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify(data)
  })
})

btnCancel.addEventListener('click', () => {
  fetch(`https://${GetParentResourceName()}/recruit:close`, { method: 'POST' })
})

window.addEventListener('message', (e) => {
  if (e.data && e.data.action === 'openRecruit') openRecruit(e.data.schema || [])
  if (e.data && e.data.action === 'closeRecruit') closeRecruit()
})

const cac = document.getElementById('cac')
const cacName = document.getElementById('cac-name')
const cacRank = document.getElementById('cac-rank')

function openCAC(name, rank) {
  cacName.textContent = name || ''
  cacRank.textContent = rank || ''
  cac.classList.remove('hidden')
}

function closeCAC() {
  cac.classList.add('hidden')
  fetch(`https://${GetParentResourceName()}/closeCAC`, { method: 'POST' })
}

window.addEventListener('message', e => {
  if (e.data && e.data.action === 'openCAC') openCAC(e.data.name, e.data.rank)
})

document.addEventListener('keydown', ev => {
  if (ev.key === 'Escape' || ev.key === 'Backspace') {
    closeCAC()
  }
})

let thNode=document.getElementById('transport-hint')
let thText=document.getElementById('transport-hint-text')
let thBar=document.getElementById('transport-hint-bar')
let thHide=null
let thTick=null

function showTransportHint(text,duration){
  thText.textContent=text||''
  thNode.classList.remove('thidden')
  thNode.classList.add('tshow')
  if(thHide) clearTimeout(thHide)
  if(thTick) clearInterval(thTick)
  if(!duration||parseInt(duration,10)===0){
    thBar.style.width='0%'
    return
  }
  thBar.style.width='100%'
  const dur=Math.max(1000,parseInt(duration,10))
  const t0=Date.now()
  thTick=setInterval(()=>{
    const left=Math.max(0,dur-(Date.now()-t0))
    const pct=left/dur*100
    thBar.style.width=pct+'%'
    if(left<=0) clearInterval(thTick)
  },100)
  thHide=setTimeout(hideTransportHint,dur)
}

function hideTransportHint(){
  if(thHide) clearTimeout(thHide)
  if(thTick) clearInterval(thTick)
  thNode.classList.remove('tshow')
  thNode.classList.add('thidden')
  thText.textContent=''
  thBar.style.width='0%'
}

window.addEventListener('message',e=>{
  if(!e.data) return
  if(e.data.action==='hint_show') showTransportHint(e.data.text||'',e.data.duration||0)
  if(e.data.action==='hint_hide') hideTransportHint()
})
