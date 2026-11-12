// Utilidades compartidas
const DAYN=["dom","lun","mar","mié","jue","vie","sáb"];
const DAYL=["domingo","lunes","martes","miércoles","jueves","viernes","sábado"];
const MON=["enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"];
const $=id=>document.getElementById(id);
const sb=window.supabase.createClient(AGENDI_CONFIG.SUPABASE_URL,AGENDI_CONFIG.SUPABASE_ANON_KEY);

// "2026-11-12" -> Date local (sin problemas de zona horaria)
function parseDay(s){const [y,m,d]=s.split("-").map(Number);return new Date(y,m-1,d)}
function dayStr(d){return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0")+"-"+String(d.getDate()).padStart(2,"0")}
function hhmm(min){return String(Math.floor(min/60)).padStart(2,"0")+":"+String(min%60).padStart(2,"0")}
function longDay(d){return `${DAYL[d.getDay()]} ${d.getDate()} de ${MON[d.getMonth()]}`}

// Número para wa.me. Uruguay: 099123456 -> 59899123456
function waNumber(raw){
  let d=String(raw||"").replace(/\D/g,"");
  if(d.startsWith("00")) d=d.slice(2);
  if(d.length===9&&d.startsWith("0")) d="598"+d.slice(1);
  else if(d.length===8&&d.startsWith("9")) d="598"+d;
  return d;
}
function waLink(number,text){return "https://wa.me/"+waNumber(number)+"?text="+encodeURIComponent(text)}

function press(container,btn){container.querySelectorAll("[aria-pressed]").forEach(b=>b.setAttribute("aria-pressed","false"));btn.setAttribute("aria-pressed","true")}
