-- Pure Lua gesture measurements; time is the backend's wrapping u32 millis.
local K = {}
function K.new(options)
    return setmetatable({ points={}, elapsed=0, vx=0, vy=0, ax=0, ay=0,
        window_ms=options.window_ms, stale_ms=options.stale_ms }, {__index=K})
end
function K:sample(time,x,y)
    if self.time then
        local dt=(time-self.time)%4294967296
        if dt==0 or dt>2147483648 then return end
        self.elapsed=self.elapsed+dt
    end
    self.time=time
    local points=self.points
    points[#points+1]={t=self.elapsed/1000,x=x,y=y}
    while #points>2 and (self.elapsed/1000-points[1].t)*1000>self.window_ms do table.remove(points,1) end
    local span=points[#points].t-points[1].t
    if span<=0 then return end
    if #points<3 then
        self.vx=(points[#points].x-points[1].x)/span
        self.vy=(points[#points].y-points[1].y)/span
        self.ax=0;self.ay=0
        return
    end
    -- Fit x/y = c0 + c1*u + c2*u² over a short recent window.
    -- u=0 at the latest sample; scaling to [-1,0] keeps the solve conditioned.
    -- c1/span is endpoint velocity, rather than velocity at the window centre.
    local matrix={}
    for i=0,2 do
        local row={0,0,0,0,0}
        for _,p in ipairs(points) do
            local u=(p.t-points[#points].t)/span
            for j=0,2 do row[j+1]=row[j+1]+u^(i+j) end
            row[4]=row[4]+p.x*u^i;row[5]=row[5]+p.y*u^i
        end
        matrix[i+1]=row
    end
    for col=1,3 do
        local pivot=col
        for row=col+1,3 do if math.abs(matrix[row][col])>math.abs(matrix[pivot][col]) then pivot=row end end
        matrix[col],matrix[pivot]=matrix[pivot],matrix[col]
        local d=matrix[col][col]
        if math.abs(d)<1e-12 then return end
        for j=col,5 do matrix[col][j]=matrix[col][j]/d end
        for row=1,3 do
            if row~=col then
                local factor=matrix[row][col]
                for j=col,5 do matrix[row][j]=matrix[row][j]-factor*matrix[col][j] end
            end
        end
    end
    self.vx=matrix[2][4]/span;self.vy=matrix[2][5]/span
    self.ax=2*matrix[3][4]/span^2;self.ay=2*matrix[3][5]/span^2
end
function K:release(time)
    local age=(time-self.time)%4294967296
    if age>=self.stale_ms then return 0,0 end
    local decay=math.exp(-age/self.stale_ms)
    return self.vx*decay,self.vy*decay
end
function K.spring(velocity,remaining,settings)
    settings=settings or {}
    return {easing={spring={stiffness=settings.stiffness or 300,
        damping=settings.damping or 25,mass=settings.mass or 1,
        initial_velocity=math.abs(remaining)>0.000001 and velocity/remaining or 0}}}
end
return K
