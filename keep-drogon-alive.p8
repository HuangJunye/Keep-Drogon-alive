pico-8 cartridge // http://www.pico-8.com
version 21
__lua__
-- math.p8
-- by decodoku
math = {}
math.pi = 3.14159
math.max = max
math.sqrt = sqrt
math.floor = flr
function math.random()
  return rnd(1)
end
function math.cos(theta)
  return cos(theta/(2*math.pi))
end
function math.sin(theta)
  return -sin(theta/(2*math.pi))
end
function math.randomseed(time)
end
os = {}
function os.time()
end
-->8
-- microqiskit-lua
-- by decodoku
math.randomseed(os.time())

function quantumcircuit ()

  local qc = {}

  local function set_registers (n,m)
    qc._n = n
    qc._m = m or 0
  end
  qc.set_registers = set_registers

  qc.data = {}

  function qc.initialize (ket)
    ket_copy = {}
    for j, amp in pairs(ket) do
      if type(amp)=="number" then
        ket_copy[j] = {amp, 0}
      else
        ket_copy[j] = {amp[0], amp[1]}
      end
    end
    qc.data = {{'init',ket_copy}}
  end

  function qc.add_circuit (qc2)
    qc._n = math.max(qc._n,qc2._n)
    qc._m = math.max(qc._m,qc2._m)
    for g, gate in pairs(qc2.data) do
      qc.data[#qc.data+1] = ( gate )    
    end
  end
      
  function qc.x (q)
    qc.data[#qc.data+1] = ( {'x',q} )
  end

  function qc.rx (theta,q)
    qc.data[#qc.data+1] = ( {'rx',theta,q} )
  end

  function qc.h (q)
    qc.data[#qc.data+1] = ( {'h',q} )
  end

  function qc.cx (s,t)
    qc.data[#qc.data+1] = ( {'cx',s,t} )
  end

  function qc.measure (q,b)
    qc.data[#qc.data+1] = ( {'m',q,b} )
  end

  function qc.rz (theta,q)
    qc.h(q)
    qc.rx(theta,q)
    qc.h(q)
  end

  function qc.ry (theta,q)
    qc.rx(math.pi/2,q)
    qc.rz(theta,q)
    qc.rx(-math.pi/2,q)
  end

  function qc.z (q)
    qc.rz(math.pi,q)
  end

  function qc.y (q)
    qc.z(q)
    qc.x(q)
  end

  return qc

end

function simulate (qc, get, shots)

  if not shots then
    shots = 1024
  end

  function as_bits (num,bits)
    -- returns num converted to a bitstring of length bits
    -- adapted from https://stackoverflow.com/a/9080080/1225661
    local bitstring = {}
    for index = bits, 1, -1 do
        b = num - math.floor(num/2)*2
        num = math.floor((num - b) / 2)
        bitstring[index] = b
    end
    return bitstring
  end

  function get_out (j)
    raw_out = as_bits(j-1,qc._n)
    out = ""
    for b=0,qc._m-1 do
      if output_map[b] then
        out = raw_out[qc._n-output_map[b]]..out
      end
    end
    return out
  end


  ket = {}
  for j=1,2^qc._n do
    ket[j] = {0,0}
  end
  ket[1] = {1,0}

  output_map = {}

  for g, gate in pairs(qc.data) do

    if gate[1]=='init' then

      for j, amp in pairs(gate[2]) do
          ket[j] = {amp[1], amp[2]}
      end

    elseif gate[1]=='m' then

      output_map[gate[3]] = gate[2]

    elseif gate[1]=="x" or gate[1]=="rx" or gate[1]=="h" then

      j = gate[#gate]

      for i0=0,2^j-1 do
        for i1=0,2^(qc._n-j-1)-1 do
          b1=i0+2^(j+1)*i1 + 1
          b2=b1+2^j

          e = {{ket[b1][1],ket[b1][2]},{ket[b2][1],ket[b2][2]}}

          if gate[1]=="x" then
            ket[b1] = e[2]
            ket[b2] = e[1]
          elseif gate[1]=="rx" then
            theta = gate[2]
            ket[b1][1] = e[1][1]*math.cos(theta/2)+e[2][2]*math.sin(theta/2)
            ket[b1][2] = e[1][2]*math.cos(theta/2)-e[2][1]*math.sin(theta/2)
            ket[b2][1] = e[2][1]*math.cos(theta/2)+e[1][2]*math.sin(theta/2)
            ket[b2][2] = e[2][2]*math.cos(theta/2)-e[1][1]*math.sin(theta/2)
          elseif gate[1]=="h" then
            for k=1,2 do
              ket[b1][k] = (e[1][k] + e[2][k])/math.sqrt(2)
              ket[b2][k] = (e[1][k] - e[2][k])/math.sqrt(2)
            end
          end

        end
      end

    elseif gate[1]=="cx" then

      s = gate[2]
      t = gate[3]

      if s>t then
        h = s
        l = t
      else
        h = t
        l = s
      end

      for i0=0,2^l-1 do
        for i1=0,2^(h-l-1)-1 do
          for i2=0,2^(qc._n-h-1)-1 do
            b1 = i0 + 2^(l+1)*i1 + 2^(h+1)*i2 + 2^s + 1
            b2 = b1 + 2^t
            e = {{ket[b1][1],ket[b1][2]},{ket[b2][1],ket[b2][2]}}
            ket[b1] = e[2]
            ket[b2] = e[1]
          end
        end
      end

    end

  end

  if get=="statevector" then
    return ket
  else

    probs = {}
    for j,amp in pairs(ket) do
      probs[j] = amp[1]^2 + amp[2]^2
    end

    if get=="fast counts" then

      c = {}
      for j,p in pairs(probs) do
        out = get_out(j)
        if c[out] then
          c[out] = c[out] + probs[j]*shots
        else
          if out then -- in case of pico8 weirdness
            c[out] = probs[j]*shots
          end
        end
      end
      return c

    else

      m = {}
      for s=1,shots do
        cumu = 0
        un = true
        r = math.random()
        for j,p in pairs(probs) do
          cumu = cumu + p
          if r<cumu and un then
            m[s] = get_out(j)
            un = false
          end
        end
      end

      if get=="memory" then
        return m

      elseif get=="counts" then
        c = {}
        for s=1,shots do
          if c[m[s]] then
            c[m[s]] = c[m[s]] + 1
          else
            if m[s] then -- in case of pico8 weirdness
              c[m[s]] = 1
            else
              if c["error"] then
                c["error"] = c["error"]+1
              else
                c["error"] = 1
              end
            end
          end
        end
        return c

      end

    end

  end

end
-->8
-- keep drogon alive
-- by Kirais & llunapuert

function _init()
  t=0

  drogon = {
    sp=0,
    x=59,
    y=5,
    h=3,
    p=0,
    t=0,
    imm=false,
    box = {x1=0,y1=0,x2=7,y2=7}
  }
  crossbow = {
    sp=16,
    x=59,
    y=110
  }
  arrows = {}
  start()
end

function start()
  _update = update_game
  _draw = draw_game
end

function game_over()
  _update = update_over
  _draw = draw_over
end

function update_over()
end

function draw_over()
  cls()
  print("game over",50,50,4)
end

function abs_box(s)
 local box = {}
 box.x1 = s.box.x1 + s.x
 box.y1 = s.box.y1 + s.y
 box.x2 = s.box.x2 + s.x
 box.y2 = s.box.y2 + s.y
 return box
end

function coll(a,b)
  box_a = abs_box(a)
  box_b = abs_box(b)

  if box_a.x1 > box_b.x2 or
    box_a.y1 > box_b.y2 or
    box_b.x1 > box_a.x2 or
    box_b.y1 > box_a.y2 then
    return false
  end

  return true
end

function shoot()
  local a = {
    sp=32,
    x=crossbow.x,
    y=crossbow.y,
    dx=0,
    dy=-1,
    box = {x1=3,y1=4,x2=5,y2=7}
  }
  add(arrows,a)
end

function update_game()
  t+=1
  if drogon.imm then
    drogon.t+=1
    if drogon.t>30 then
      drogon.imm=false
      drogon.t=0
    end
  end

  for a in all(arrows) do
    a.x+=a.dx
    a.y+=a.dy
    if a.x<0 or a.x>128 or
      a.y<0 or a.y>128 then
      del(arrows,a)
    end
    if coll(a,drogon) and not drogon.imm then
      del(arrows,a)
      drogon.imm=true
      drogon.h-=1
      if drogon.h<=0 then game_over() end      
    end
  end

  if(t%6<3) then
    drogon.sp=0
  else
    drogon.sp=1
  end

  if (t%20==0) then shoot() end

  if btn(0) then drogon.x-=1 end
  if btn(1) then drogon.x+=1 end
  if btn(2) then drogon.y-=1 end
  if btn(3) then drogon.y+=1 end

end

function draw_game()
  cls()
  print(drogon.p,9)
  if not drogon.imm or t%8 < 4 then
    spr(drogon.sp,drogon.x,drogon.y)
  end
  
  for a in all(arrows) do
    spr(a.sp,a.x,a.y)
  end

  spr(crossbow.sp,crossbow.x,crossbow.y)

  for i=1,4 do
    if i<=drogon.h then 
      spr(48,98+6*i,3)
    else
      spr(49,98+6*i,3)
    end
  end
end
__gfx__
50078005000780000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25088052050880500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22588522525885250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
52282225222822220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05282250252822520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00588500005885000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00208208802802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000820028000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400004444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04040040040400400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
40040004400400040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddddd04000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000000d400d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000000ddd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08080000060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888000666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08880000066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
