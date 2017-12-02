-- title:  Moreworse
-- author: Martin Sandgren
-- desc:   Protect!
-- script: lua
-- input:  mouse

--{{{ HEADER
cash = 300
mpress = false
mhold = false
mx = 0
my = 0
t = 0
fiscal = 0
house = {152, 72}
cb_ui = nil

actor_type_bandit = 1
actor_type_guard = 2

--}}}
--{{{ ACTORS
actors = {}

function actor_add(type, tic, x, y)
	actor = {
		type=type,
		tic=tic,
		spr=0, spr_rot=0, spr_flip=0,
		x=x, y=y,
		next_tic=0,
		dead=false,
	}

	table.insert(actors, #actors+1, actor)
	return actor
end

function tic_actors()
	for i, a in ipairs(actors) do
		local draw = true

		if a.dead == false then
			a.next_tic = a.next_tic - 1

			if a.next_tic <= 0 then
				a.next_tic = a.tic(a)
			end
		else
			if a.next_tic <= 0 then
				draw = false
				table.remove(actors, i)
			end
		end

		if draw then
			spr(a.spr, a.x, a.y, 0, 1, a.spr_flip, a.spr_rot)
		end
	end
end
--}}}
--{{{ BANDITS
bandit_next = 400
bandit_timer = 300
bandit_waves = 0

function bandit_new(x, y)
	local a = actor_add(actor_type_bandit, function(a)
		a.t = a.t+1
		local frame = 273 + ((a.t // 20) % 2)
		a.spr = frame

		a.x = a.x + a.dx
		a.y = a.y + a.dy

		local at_row = mget(
		(a.x+4)//8,
		(a.y+4)//8) // 16
		if at_row == 5 or at_row == 6 then
			a.dead = true
			a.next_tic = 0
			a.spr = 0
			cash_steal(100)
		end

		return 1
	end, x, y)

	a.spr = 272
	a.health = 3
	a.t = 0
	a.next_tic = 40

	a.dx = house[1] - a.x
	a.dy = house[2] - a.y

	local r_inv = 1.0 / math.sqrt(a.dx*a.dx + a.dy*a.dy)
	a.dx = a.dx * r_inv * 0.3
	a.dy = a.dy * r_inv * 0.3
end

function bandit_hit(a, damage)
	a.health = a.health - damage
	if a.health <= 0 then
		a.dead = true
		a.next_tic = 120
		a.spr = 275
		a.spr_rot = math.floor(math.random()*3.999)
		a.spr_flip = math.floor(math.random()*3.999)
	end
end

function bandit_wave()
	bandit_waves = bandit_waves+1

	local y_start = -6
	if (bandit_waves // 2) % 2 == 1 then
		y_start = 134
	end

	for i = 1, bandit_waves do
		local x_start = math.random() * 240
		bandit_new(x_start, y_start)
	end
end

function bandit_tic()
	bandit_timer = bandit_timer+1

	if bandit_timer >= bandit_next then
		bandit_timer = 0
		bandit_wave()
		return true
	end

	return false
end

function bandit_clear()
	for i, a in ipairs(actors) do
		if a.type == actor_type_bandit then
			--table.delete(actors, i)
		end
	end
end
--}}}
--{{{ LINES
lines = {}

function lines_tic()
	for i, l in ipairs(lines) do
		line(l.x0, l.y0, l.x1, l.y1, l.color)
		l.ttl = l.ttl - 1
		if l.ttl <= 0 then
			table.remove(lines, i)
		end
	end
end

function lines_add(x0, y0, x1, y1, col, duration)
	table.insert(lines, #lines+1, {
		x0=x0, y0=y0, x1=x1, y1=y1, color=col, ttl=duration,
	})
end
--}}}
--{{{ GUARD ACTOR
guard_count = 0
guard_range = 90
guard_rate = 25

function guard_new(x, y)
	local a = actor_add(actor_type_guard, function(a)
		a.autoturn = a.autoturn-1

		if guard_attack(a) then
			return guard_rate + math.floor(math.random()*10)
		elseif a.autoturn <= 0 then
			a.autoturn = 3 + math.floor(math.random()*2)

			if math.random() > 0.5 then
				a.spr = a.spr + 1
			else
				a.spr = a.spr - 1
			end

			if a.spr >= 256+8 then
				a.spr = 256
			elseif a.spr < 256 then
				a.spr = 256 + 7
			end
		end

		return 10
	end, x, y)
	a.spr = 256
	a.autoturn = 0

	guard_count = guard_count + 1
	cash_balance(-50)
end

function guard_attack(g)
	for i, a in ipairs(actors) do
		if a.type == actor_type_bandit and a.dead == false then
			local dx = a.x - g.x
			local dy = a.y - g.y

			if math.abs(dx)+math.abs(dy) < guard_range then
				--local angle = (4 - math.floor(
				--2 * (math.atan2(dx, dy) + math.pi))) % 8
				local angle = math.atan2(dx, dy) + math.pi
				local frame_id = (4- math.floor(
				8.0*angle / (math.pi*2)))%8

				local dist_inv = 1.0 / math.sqrt(dx*dx + dy*dy)

				lines_add(
					g.x+4 + dx*dist_inv*5,
					g.y+4 + dy*dist_inv*5,
					a.x+4,
					a.y+4,
					9, 5)
				sfx(1)
				bandit_hit(a, 1)

				g.spr = 256 + frame_id
				return true
			end
		end
	end

	return false
end

function guard_upgrade_range()
	guard_range = guard_range+20
end

function guard_upgrade_rate()
	guard_rate = guard_rate-10
end

function guard_get_at(x, y)
	local tx = x // 8
	local ty = y // 8
end
--}}}
--{{{ UI ELEMENTS
function mouse_in_rect(r)
	return
	mx >= r[1] and
	mx <= r[1]+r[3] and
	my >= r[2] and
	my <= r[2]+r[4]
end

function draw_shadow_text(text, x, y, color)
	print(text, x+1, y+1, 0)
	print(text, x, y, color)
end

function tile_at(mx, my)
	return mget(mx//8, my//8)
end

function draw_cash()
	draw_shadow_text("CASH: "..cash, 160, 10, 13)
end

function draw_rect(r)
	rect(r[1], r[2], r[3], r[4], 1)
end

function draw_meny()
	rect(200, 0, 120, 136, 15)
end

function draw_button(r, text, afford)
	local x1 = r[1] + r[3]
	local y1 = r[2] + r[4]

	local line_color = 8
	if afford == false then
		line_color = 6
	end

	local mouse_in = mouse_in_rect(r)
	if mouse_in then
		line_color = 11
	end

	draw_rect(r, 3)
	line(r[1], r[2], x1, r[2], line_color)
	line(r[1], y1, x1, y1, line_color)
	line(r[1], r[2], r[1], y1, line_color)
	line(x1, r[2], x1, y1, line_color)
	print(text, r[1]+2, r[2]+2)

	return mouse_in and mpress
end

function invest_button(id, cost, text)
	local r = {15, 25 + id*10, 90, 8}
	local afford = cash-cost >= 0
	if draw_button(r, text, afford) and afford then
		cash = cash-cost
		return true
	else
		return false
	end
end
--}}}
--{{{ UI
rect_invest_btn = {10, 120, 40, 8}

rect_buy_area = {10, 10, 100, 100}
rect_buy_guard_btn = {15, 25, 90, 8}
rect_buy_tower_btn = {15, 35, 90, 8}
rect_buy_back_btn = {15, 70, 30, 8}

function ui_normal()
	draw_cash()
	local press = draw_button(rect_invest_btn, "INVEST")

	if press then
		cb_ui = ui_invest
	end
end

function ui_invest()
	draw_rect(rect_buy_area)
	draw_shadow_text("Investors menu", 13, 13, 14)
	draw_cash()

	if invest_button(0, 30, "GUARD (30 + 40X)") then
		cb_ui = ui_place_guard
	end

	if invest_button(1, 400, "EXTRA TOWER (400)") then
		build_tower()
		cb_ui = ui_normal
	end

	if invest_button(2, 250, "UPGRADE RANGE (250)") then
		cb_ui = ui_place_guard
		guard_upgrade_range()
		cb_ui = ui_normal
	end

	if invest_button(3, 250, "UPGRADE FIRE RATE (250)") then
		cb_ui = ui_place_guard
		guard_upgrade_rate()
		cb_ui = ui_normal
	end

	if draw_button(rect_buy_back_btn, "Back") then
		cb_ui = ui_normal
	end
end

function ui_place_guard()
	draw_shadow_text("Place guard on top of building",
	13, 13, 15)

	if mpress then
		local tile = tile_at(mx, my)
		if tile // 16 == 5 then
			cb_ui = ui_normal
			guard_new((mx // 8)*8, (my // 8)*8)
		end
	end
end
--}}}
--{{{ CASH
function cash_steal(amount)
	trace("LOST "..amount.." CASH")
	cash = cash-amount
end

function cash_balance(amount)
	cash = cash+amount
end

function cash_fisical()
	sfx(2)
	cash = math.ceil(cash * 1.2)
	cash_balance(-guard_count*40)
	bandit_clear()
end
--}}}
--{{{ MISC
function build_tower()
	local offset_a = {9, 6}
	local offset_b = {0, 17}
	for y = 0, 4 do
		for x = 0, 2 do
			local get = mget(
				offset_b[1]+x,
				offset_b[2]+y)
			mset(
				offset_a[1]+x,
				offset_a[2]+y,
				get)
		end
	end
end
--}}}
--{{{ MAIN

function init()
	sfx(0)

	cb_ui = ui_normal
	--cb_ui = ui_invest
	cb_ui = ui_place_guard
end

function TIC()
	t = t+1
	fiscal = fiscal+1

	map(0, 0, 30, 17, 0, 0)

	local mfpress
	mx, my, mfpress = mouse()
	mpress = (mhold == false) and mfpress
	mhold = mfpress

	if bandit_tic() then
		cash_fisical()
	end

	tic_actors()
	lines_tic()
	cb_ui()
end

init()
--}}}
