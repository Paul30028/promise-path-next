import { useEffect, useState } from 'react';
import type { CSSProperties } from 'react';
import World from './World';
import { hasSavedGame, loadGame, newGame, order, pushLog, saveGame, targets, tick } from './game';
import type { Game, Order } from './game';
import { actorNames, copy, loadLanguage, localizeLog, localizeOrder, saveLanguage } from './i18n';
import type { CopyKey, Language } from './i18n';

const roles = { leader:'leader', organizer:'organizer', herdsman:'herdsman', scout:'scoutRole', carrier:'carrierRole', builder:'builder', elder:'elder' } as const;
const actions = [
  { kind:'water', label:'取水', title:'carrier', detail:'carrierDetail', sign:'◉', target:targets.spring },
  { kind:'timber', label:'收集木料', title:'gather', detail:'gatherDetail', sign:'≋', target:targets.wood },
  { kind:'build', label:'搭建帐棚', title:'build', detail:'buildDetail', sign:'⌂', target:targets.tentWork },
  { kind:'scout', label:'侦察山脊', title:'scout', detail:'scoutDetail', sign:'⌁', target:targets.ridge },
  { kind:'talk', label:'与罗得交谈', title:'talk', detail:'talkDetail', sign:'✧', target:targets.lot },
] as const;

export default function App() {
  const [game,setGame] = useState<Game>(loadGame);
  const [selected,setSelected] = useState<string[]>(['abram']);
  const [panel,setPanel] = useState<'story'|'help'|null>(()=>hasSavedGame()?null:'story');
  const [saved,setSaved] = useState(true);
  const [language,setLanguage] = useState<Language>(loadLanguage);
  const t=(key:CopyKey)=>copy[language][key];
  useEffect(()=>{ saveLanguage(language); document.documentElement.lang=language==='zh'?'zh-CN':'en'; document.title=`${copy[language].title} · ${copy[language].camp}`; },[language]);
  useEffect(()=>{ const id=window.setInterval(()=>setGame(g=>tick(g)),80); return ()=>window.clearInterval(id); },[]);
  useEffect(()=>{ setSaved(saveGame(game)); },[game]);
  function select(id:string){ setSelected(ids=>ids.includes(id)?ids.filter(x=>x!==id):[...ids,id]); }
  function assign(task:Order){
    if (!selected.length) { setGame(g=>pushLog(g,'先选择一名队员。')); return; }
    setGame(g=>pushLog({ ...g, actors:g.actors.map(a=>selected.includes(a.id)?{...a,queue:[...a.queue,task]}:a) },`${selected.length} 名队员收到「${task.label}」指令${g.paused?'，恢复后执行。':'。'}`));
  }
  function resolve(choice:'share'|'separate'){
    setGame(g=>{ if(g.story!=='dispute') return g; const next = choice==='share' ? { ...g,water:Math.max(0,g.water-2),trust:g.trust+2,story:'resolved' as const,ending:'先共用泉水，双方平静地准备分开牧放。营地储水减少，关系缓和。罗得随后先选了约旦河平原。' } : { ...g,herd:Math.max(0,g.herd-1),trust:g.trust+1,story:'resolved' as const,ending:'立即迁移，转移时一只羊走失。罗得先选了约旦河平原，亚伯兰留在迦南。' }; return pushLog(next,next.ending); }); setPanel(null);
  }
  const busy=game.actors.filter(a=>a.queue.length).length;
  const lead=game.actors.find(a=>a.id===selected[0]);
  const objective = game.ending ? t('objectiveEnd') : game.encounter==='active' ? t('objectiveThreat') : game.tents<1 ? t('objectiveBuild') : game.encounter==='hidden' ? t('objectiveScout') : t('objectiveTalk');
  return <main className={`game-shell ${language==='en'?'lang-en':''}`}>
    <section className="game-layout">
      <div className="viewport">
        <World game={game} selected={selected} select={select} move={(x,z)=>assign(order('move','移动',x,z))}/>
        <div className="scene-shade" aria-hidden="true"/>
        <div className="scene-heading"><span className="chapter-num">{t('chapter')}</span><strong>{t('place')}</strong><span>{t('source')}</span></div>
        <div className="scene-bottom"><span className="scene-dot"/><div><b>{game.paused?t('waiting'):t('working')}</b><small>{t('moveHint')}</small></div></div>
        <div className="event-toast" role="status">{localizeLog(game.log[0],language)}</div>
      </div>
      <aside className="command-panel" aria-label={t('camp')}>
        <div className="panel-top"><div className="wordmark"><span className="sigil">✦</span><span><strong>{t('title')}</strong><small>{t('camp')}</small></span></div><div className="panel-tools"><button className="lang-button" onClick={()=>setLanguage(language==='zh'?'en':'zh')} aria-label={language==='zh'?'Switch to English':'切换为中文'}>{language==='zh'?'EN':'中'}</button><button className="icon-button" onClick={()=>setPanel('help')} aria-label={t('help')} title={t('help')}>?</button></div></div>
        <div className="panel-scroll">
          <div className="objective"><div className="objective-top"><span>{t('objective')}</span><span>{t('objectiveRef')}</span></div><h1>{t('chapterTitle')}</h1><p>{objective}</p><div className="progress"><span className="done">{t('arrived')}</span><span className={game.tents>0?'done':''}>{t('setCamp')}</span><span className={game.encounter==='ended'?'done':''}>{t('scoutStep')}</span><span className={game.story==='resolved'?'done':''}>{t('decide')}</span></div></div>
          <div className="supply-strip" aria-label={t('camp')}><div><small>{t('water')}</small><b>{game.water}</b></div><div><small>{t('timber')}</small><b>{game.timber}</b></div><div><small>{t('tents')}</small><b>{game.tents}</b></div><div><small>{t('herd')}</small><b>{game.herd}</b></div><div><small>{t('trust')}</small><b>{game.trust}</b></div></div>
          <div className="group-head"><h2>{t('squad')}</h2><span>{selected.length} {t('selected')} · {busy} {t('busy')}</span></div>
          <div className="roster">{game.actors.map(a=>{const name=actorNames[a.id]?.[language]??a.name;const role=t(roles[a.role]);return <button key={a.id} className={`actor ${selected.includes(a.id)?'active':''}`} aria-pressed={selected.includes(a.id)} onClick={()=>select(a.id)} title={`${name} · ${role} · ${t('energy')} ${Math.round(a.energy)}`}><span className="portrait" style={{'--actor-color':a.color} as CSSProperties}>{name.slice(0,1)}</span><b>{name}</b><small>{role}</small>{a.queue.length>0&&<i className="queue-count">{a.queue.length}</i>}</button>})}</div>
          <div className="group-head action-head"><h2>{t('actions')}</h2><span>{t('inOrder')}</span></div>
          <div className="actions">{actions.map(a=><button key={a.kind} disabled={a.kind==='talk'&&(game.tents<1||game.encounter!=='ended')} onClick={()=>assign(order(a.kind,a.label,a.target.x,a.target.z))} title={t(a.detail)}><span className="action-sign">{a.sign}</span><span><b>{t(a.title)}</b><small>{t(a.detail)}</small></span></button>)}</div>
          {game.encounter==='active' && <><div className="group-head"><h2>{t('tactical')}</h2><span>{t('tacticalHint')}</span></div><div className="cards"><button onClick={()=>assign(order('defend','警戒驱离',targets.threat.x,targets.threat.z))}><b>{t('defend')}</b><small>{t('defendDetail')}</small></button><button disabled={game.timber<1} onClick={()=>assign(order('torch','火把威慑',targets.threat.x,targets.threat.z))}><b>{t('torch')}</b><small>{t('timber')} −1</small></button><button disabled={game.water<1} onClick={()=>assign(order('retreat','转移羊群',targets.threat.x,targets.threat.z))}><b>{t('retreat')}</b><small>{t('water')} −1</small></button></div></>}
          <div className="selected-info"><div className="group-head"><h2>{t('selectedPerson')}</h2><span>{lead?actorNames[lead.id]?.[language]??lead.name:''}</span></div>{lead?<><div className="stamina-line"><span>{t('energy')}</span><div><span style={{width:`${lead.energy}%`}}/></div><b>{Math.round(lead.energy)}</b></div><div className="orders-preview"><small>{t('nextOrders')}</small><p>{lead.queue.length?lead.queue.map(q=>localizeOrder(q.label,language)).join(' → '):t('idle')}</p></div></>:<p className="empty-selection">{t('choosePerson')}</p>}</div>
        </div>
        <div className="command-dock"><div className="dock-state"><span className={game.paused?'pause-mark':'play-mark'}>{game.paused?'Ⅱ':'▶'}</span><div><b>{game.paused?t('paused'):t('running')}</b><small>{saved?t('saved'):t('saveFailed')}</small></div></div><button className="clear-button" onClick={()=>setGame(g=>pushLog({...g,actors:g.actors.map(a=>selected.includes(a.id)?{...a,queue:[]}:a)},'已清空所选队员的指令。'))}>{t('clear')}</button><button className="execute-button" onClick={()=>setGame(g=>({...g,paused:!g.paused}))}>{game.paused?t('execute'):t('pause')} <span>{game.paused?'▶':'Ⅱ'}</span></button></div>
      </aside>
    </section>
    <button className="restart-button" onClick={()=>{ if(window.confirm(t('restartConfirm'))) { setGame(newGame()); setSelected(['abram']); setPanel('story'); } }}>{t('restart')}</button>
    {game.story==='dispute' && !game.ending && <div className="overlay"><div className="dialog"><button className="dialog-lang" onClick={()=>setLanguage(language==='zh'?'en':'zh')}>{language==='zh'?'EN':'中'}</button><span className="eyebrow">{t('choiceRef')}</span><h2>{t('dispute')}</h2><p>{t('disputeBody')}</p><div className="choice"><button disabled={game.water<2} onClick={()=>resolve('share')}><b>{t('share')}</b><small>{t('shareCost')}</small></button><button onClick={()=>resolve('separate')}><b>{t('separate')}</b><small>{t('separateCost')}</small></button></div><p className="note">{t('adaptationNote')}</p></div></div>}
    {panel && game.story!=='dispute' && <div className="overlay" onClick={()=>setPanel(null)}><div className="dialog" onClick={e=>e.stopPropagation()}><button className="close" onClick={()=>setPanel(null)}>×</button><button className="dialog-lang" onClick={()=>setLanguage(language==='zh'?'en':'zh')}>{language==='zh'?'EN':'中'}</button>{panel==='story'?<><span className="eyebrow">{t('storyIntro')}</span><h2>{t('arrival')}</h2><p>{t('arrivalBody')}</p><p className="note">{t('sourceNote')}</p></>:<><h2>{t('help')}</h2><p>{t('helpBody')}</p><p>{t('helpSteps')}</p><p className="note">{t('artNote')}</p></>}<button className="dialog-primary" onClick={()=>setPanel(null)}>{t('begin')}</button></div></div>}
  </main>;
}
