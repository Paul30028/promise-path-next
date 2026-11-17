import { useEffect, useState } from 'react';
import World from './World';
import { loadGame, newGame, order, pushLog, saveGame, targets, tick } from './game';
import type { Game, Order } from './game';

const roles = { leader:'领队',organizer:'管事',herdsman:'牧人',scout:'侦察',carrier:'取水',builder:'工匠',elder:'长者' };
export default function App() {
  const [game,setGame] = useState<Game>(loadGame);
  const [selected,setSelected] = useState<string[]>(['abram']);
  const [panel,setPanel] = useState<'story'|'help'|null>('story');
  const [saved,setSaved] = useState(true);
  useEffect(()=>{ const id=window.setInterval(()=>setGame(g=>tick(g)),80); return ()=>window.clearInterval(id); },[]);
  useEffect(()=>{ setSaved(saveGame(game)); },[game]);
  function select(id:string){ setSelected(ids=>ids.includes(id)?ids.filter(x=>x!==id):[...ids,id]); }
  function assign(task:Order){
    if (!selected.length) { setGame(g=>pushLog(g,'请先选一名队员。')); return; }
    setGame(g=>pushLog({ ...g, actors:g.actors.map(a=>selected.includes(a.id)?{...a,queue:[...a.queue,task]}:a) },`${selected.length} 名队员收到「${task.label}」指令${g.paused?'，恢复后执行。':'。'}`));
  }
  function resolve(choice:'share'|'separate'){
    setGame(g=>{ if(g.story!=='dispute') return g; const next = choice==='share' ? { ...g,water:Math.max(0,g.water-2),trust:g.trust+2,story:'resolved' as const,ending:'先共用泉水，双方平静地准备分开牧放。营地储水减少，关系缓和。罗得随后先选了约旦河平原。' } : { ...g,herd:Math.max(0,g.herd-1),trust:g.trust+1,story:'resolved' as const,ending:'立即分开牧放，转移时一只羊走失。罗得先选了约旦河平原，亚伯兰留在迦南。' }; return pushLog(next,next.ending); }); setPanel(null);
  }
  const busy=game.actors.filter(a=>a.queue.length).length;
  return <main>
    <header className="topbar"><div className="brand"><span className="brand-mark">✦</span><div><strong>应许之路</strong><small>列祖旅途营地 · 可玩原型</small></div></div><div className="resources"><span>水 <b>{game.water}</b></span><span>木料 <b>{game.timber}</b></span><span>帐棚 <b>{game.tents}</b></span><span>羊群 <b>{game.herd}</b></span><span>信任 <b>{game.trust}</b></span></div><button className="quiet" onClick={()=>setPanel('help')}>操作说明</button></header>
    <section className="layout"><div className="viewport"><World game={game} selected={selected} select={select} move={(x,z)=>assign(order('move','移动',x,z))}/><div className="scene-label">迦南丘陵 · 创世记 13 章改编场景</div><div className="scene-hint">点击角色多选 · 点击地面移动 · 暂停时可连续排指令</div></div>
      <aside className="side"><div className="chapter"><span>第一幕 · 寻找落脚处</span><h1>水源与牧道</h1><p>一片土地容不下两群牲畜。安排众人寻找资源、搭起营地，再与罗得商谈去向。</p></div>
        <div className="section-title">队伍 <small>{selected.length} 人已选 · {busy} 人执行中</small></div><div className="roster">{game.actors.map(a=><button key={a.id} className={`actor ${selected.includes(a.id)?'active':''}`} onClick={()=>select(a.id)}><span className="portrait" style={{background:a.color}}>{a.name.slice(0,1)}</span><span><b>{a.name}</b><small>{roles[a.role]} · 体力 {Math.round(a.energy)}</small></span><em>{a.queue.length?`${a.queue.length} 指令`:''}</em></button>)}</div>
        <div className="section-title">行动</div><div className="actions"><button onClick={()=>assign(order('water','取水',targets.spring.x,targets.spring.z))}>◉ 泉边取水</button><button onClick={()=>assign(order('timber','收集木料',targets.wood.x,targets.wood.z))}>▰ 收集木料</button><button onClick={()=>assign(order('build','搭建帐棚',targets.tentWork.x,targets.tentWork.z))}>⌂ 搭建帐棚</button><button onClick={()=>assign(order('scout','侦察山脊',targets.ridge.x,targets.ridge.z))}>◇ 侦察山脊</button><button disabled={game.tents<1||game.encounter!=='ended'} title="先完成帐棚与羊群危险" onClick={()=>assign(order('talk','与罗得交谈',targets.lot.x,targets.lot.z))}>☷ 与罗得交谈</button></div>
        {game.encounter==='active' && <><div className="section-title">战术手牌 <small>选队员后排入队列</small></div><div className="cards"><button onClick={()=>assign(order('defend','警戒驱离',targets.threat.x,targets.threat.z))}><b>警戒驱离</b><small>领队或侦察者更稳妥</small></button><button disabled={game.timber<1} onClick={()=>assign(order('torch','火把威慑',targets.threat.x,targets.threat.z))}><b>火把威慑</b><small>木料 −1 · 保护羊群</small></button><button disabled={game.water<1} onClick={()=>assign(order('retreat','转移羊群',targets.threat.x,targets.threat.z))}><b>转移羊群</b><small>水 −1 · 羊群无损</small></button></div></>}
        <div className="controls"><button className="primary" onClick={()=>setGame(g=>({...g,paused:!g.paused}))}>{game.paused?'▶ 执行指令':'Ⅱ 暂停安排'}</button><button onClick={()=>setGame(g=>pushLog({...g,actors:g.actors.map(a=>selected.includes(a.id)?{...a,queue:[]}:a)},'已清空所选队员的指令。'))}>清空指令</button></div>
      </aside></section>
    <footer><div><b>旅途记录</b><span>{saved?'已自动存档':'存档失败'}</span></div><p>{game.log[0]}</p><button onClick={()=>{ if(window.confirm('重新开始这段旅程？当前进度会被覆盖。')) { setGame(newGame()); setSelected(['abram']); setPanel('story'); } }}>重新开始</button></footer>
    {game.story==='dispute' && !game.ending && <div className="overlay"><div className="dialog"><span className="eyebrow">剧情抉择 · 创世记 13:5—12</span><h2>牧人的争执</h2><p>罗得的牧人与亚伯兰的牧人起了争执。泉水和牧地有限，双方需要分开牧放。你可以决定怎样准备这次分离。</p><div className="choice"><button disabled={game.water<2} onClick={()=>resolve('share')}><b>先共用水源，再有序分开</b><small>消耗 2 水 · 信任 +2</small></button><button onClick={()=>resolve('separate')}><b>立即迁移，尽快分开</b><small>羊群 −1 · 信任 +1</small></button></div><p className="note">资源结果是游戏改编。经文记载亚伯兰提议分开，由罗得先选择方向。</p></div></div>}
    {panel && game.story!=='dispute' && <div className="overlay" onClick={()=>setPanel(null)}><div className="dialog" onClick={e=>e.stopPropagation()}><button className="close" onClick={()=>setPanel(null)}>×</button>{panel==='story'?<><span className="eyebrow">列祖旅途 · 第一段</span><h2>抵达丘陵</h2><p>亚伯兰与罗得的牲畜增多。你要先稳定营地：取水、备料、搭帐棚、勘察道路，然后与罗得交谈。</p><p className="note">人物与事件依据《创世记》13:1—12；其他队员姓名、野兽和资源数值为游戏创作。</p></>:<><h2>操作说明</h2><p>点击角色可多选。点击地面安排移动；右侧按钮安排工作。暂停时可排多条指令，执行时队员按顺序行动。</p><p>先给取水者安排取水，给工匠安排收木与搭棚，派侦察者前往山脊。野兽出现后，派领队或侦察者驱离。与罗得交谈会触发故事抉择。</p><p className="note">角色和营地已加载本工程制作的 glTF 模型，仍是造型样板，尚未达到 A 版商业美术质量。</p></>}<button className="primary" onClick={()=>setPanel(null)}>开始行动</button></div></div>}
  </main>;
}
