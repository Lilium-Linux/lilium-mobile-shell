-- Run with Lua 5.4 from this bundle's root. Exercises the combined policy,
-- without a compositor, clients, or synthesized hardware input.
package.path = './?.lua;' .. package.path
local handlers, kept, cards, captured, shown = {}, {}, {}, 0, {}
hold = nil
local clients = {}
for i=1,10 do clients[i]={id=i,monitor='test',app_id='app'..i,title='App '..i,w=1200,h=800} end
sol=setmetatable({
    keep=function(_,initial) kept=initial;return kept end,
    monitors=function() return {{name='test',primary=true,scale=1,whole={x=0,y=0,w=1200,h=800}}} end,
    windows=function() return clients end,
    on=function(name,fn)
        local previous=handlers[name]
        handlers[name]=previous and function(...) previous(...);fn(...) end or fn
    end,
    surface=function(name,data)
        if name=='mobile-shell' then
            local p=data.properties
            if p.cards then cards=p.cards end
            if p.hold then hold=p.hold end
        end
    end,
    touch=function() captured=captured+1 end,
    present=function(id,r) shown[id]=r end,
}, {__index=function() return function() end end})
local mobile=require('mobile.policy')
mobile.apply();mobile.select(1);mobile.recents()
assert(#cards==10)
assert(cards[1].y<cards[2].y and cards[1].x==cards[2].x,'tablet has two rows')
assert(cards[3].x>cards[1].x,'tablet columns advance horizontally')
local function event(kind,x,y,t)
    handlers.touch({kind=kind,x=x,y=y,time=t,t=t/1000,slot=0,target='scene',control=false})
end
local initial=cards[1].x
event('down',100,300,0);event('motion',50,300,40);event('motion',0,300,80);event('up',0,300,81)
assert(kept.overview_offset < -100,'tablet release retains horizontal momentum')
assert(cards[1].x<initial-100)
local saved=kept.overview_offset
event('down',100,300,200);event('motion',180,300,240);event('cancel',180,300,241)
assert(kept.overview_offset==saved,'cancel restores committed strip offset')
local before=captured
event('down',600,740,300);event('up',600,740,310)
assert(captured==before,'overview dock remains available to QML controls')
mobile.select(1)
handlers.surface('mobile-shell','mobile.home',{})
handlers.surface('mobile-shell','mobile.icons',{epoch=1,w=1200,h=800,items={app1={x=40,y=70,size=60}}})
mobile.select(1)
event('down',600,798,500);event('motion',600,720,530);event('motion',600,600,560);event('up',600,600,561)
assert(kept.page=='home','fast upward release goes home')
assert(shown[1].x==40 and shown[1].y==70 and shown[1].w==60,'gesture finishes at reported launcher icon')
mobile.select(1)
event('down',600,798,700);event('motion',600,730,740);event('cancel',600,730,741)
assert(kept.page=='app','cancelled navigation stays in app')
-- Swipe up and hold still: Recents opens while the finger is down, by the
-- chrome scene's timer, and letting go does nothing more.
mobile.select(1)
event('down',600,798,1000)
for i=1,10 do event('motion',600,798-i*30,1000+i*10) end
assert(hold and hold.token>0,'a swipe past the commit distance arms the hold timer')
for i=1,4 do event('motion',600,498,1100+i*40) end -- resting, still sending
assert(kept.page=='app','not yet: the finger has not rested long enough')
for i=5,9 do event('motion',600,498,1100+i*40) end
assert(kept.page=='recents','a swipe held still opens Recents while the finger is down')
event('up',600,498,1500)
assert(kept.page=='recents','letting go of a held swipe does nothing more')
-- The same, with a finger that sends nothing once it rests: the timer.
mobile.select(1)
event('down',600,798,2000)
for i=1,10 do event('motion',600,798-i*30,2000+i*10) end
assert(kept.page=='app')
local first=hold.token
handlers.surface('mobile-shell','mobile.hold',{token=first})
assert(kept.page=='app' and hold.token>first,'armed as the finger crossed, still moving then: armed again for the rest')
assert(hold.ms<200 and hold.ms>0)
handlers.surface('mobile-shell','mobile.hold',{token=hold.token})
assert(kept.page=='recents','the hold timer opens Recents for a finger at rest')
event('up',600,498,2400)
assert(kept.page=='recents')
-- A flick still goes home, and a stale timer does nothing.
mobile.select(1)
event('down',600,798,3000);event('motion',600,720,3030);event('motion',600,600,3060);event('up',600,600,3061)
assert(kept.page=='home','a flick still goes home')
handlers.surface('mobile-shell','mobile.hold',{token=hold.token})
assert(kept.page=='home','a timer from a finished swipe does nothing')
print('PASS: tablet grid, momentum, cancellation, dock controls, home icon destination, hold for Recents')
