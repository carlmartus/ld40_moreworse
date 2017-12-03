-- title:  Moreworse
-- author: Martin Sandgren
-- desc:   Protect!
-- script: lua
-- input:  mouse
-- dofile("code.lua")

--{{{ HEADER
colorspin = 0
mpress = false
mhold = false
mx = 0
my = 0

actor_type_bandit = 1
actor_type_guard = 2
payroll = 30

stats_kills = 0
stats_payrolled = 0
stats_thefts = 0
guard_count = 0
--}}}
--{{{ PRICES

price_guard = 40
price_upgrade_range = 100
price_upgrade_rate = 250
price_tower = 700

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

function actor_is_taken(x, y)
	for i, a in ipairs(actors) do
		if a.type == actor_type_guard then
			if a.x == x and a.y == y then
				return true
			end
		end
	end

	return false
end
--}}}
--{{{ BANDITS
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
			sfx(3)
			stats_thefts = stats_thefts+1
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
		stats_kills = stats_kills+1
		a.dead = true
		a.next_tic = 120
		a.spr = 275
		a.spr_rot = math.floor(math.random()*3.999)
		a.spr_flip = math.floor(math.random()*3.999)
		sfx(5)
	end
end

function bandit_wave()
	bandit_waves = bandit_waves+1

	local y_start = -6
	if (bandit_waves // 2) % 2 == 1 then
		y_start = 134
	end

	local count = bandit_waves + math.floor((quater*quater)/50)
	for i = 1, count do
		local x_start = math.random() * 240
		bandit_new(x_start, y_start)
	end
end

function bandit_tic()
	bandit_timer = bandit_timer+1

	if bandit_timer >= bandit_next then
		bandit_clear()
		bandit_timer = 0
		bandit_wave()
		return true
	end

	return false
end

function bandit_clear()
	local i=1
	while i <= #actors do
		if actors[i].type == actor_type_bandit then
			table.remove(actors, i)
		else
			i = i+1
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
--{{{ GUARD
guard_count = 0
guard_range = 90
guard_rate = 25

function guard_new(x, y)
	local a = actor_add(actor_type_guard, function(a)
		a.autoturn = a.autoturn-1

		if guard_attack(a) then
			return guard_rate + math.floor(math.random()*10)
		elseif a.autoturn <= 0 then
			a.last_target = nil
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
	a.last_target = nil

	guard_count = guard_count + 1
end

function guard_shoot(g, a)
	local dx = a.x - g.x
	local dy = a.y - g.y
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
	sfx(1, 20+12*math.floor(math.random()*2), 30, 1)
	bandit_hit(a, 1)

	g.spr = 256 + frame_id
end

function guard_attack(g)
	if g.last_target and g.last_target.dead == false then
		guard_shoot(g, g.last_target)
		return true
	else
		g.last_target = nil
	end

	for i, a in ipairs(actors) do
		if a.type == actor_type_bandit and a.dead == false then
			local dx = a.x - g.x
			local dy = a.y - g.y

			if math.abs(dx)+math.abs(dy) < guard_range then
				guard_shoot(g, a)
				g.last_target = a
				return true
			end
		end
	end

	return false
end

function guard_upgrade_range()
	guard_range = guard_range+20
	done_upgrade_range = true
end

function guard_upgrade_rate()
	guard_rate = guard_rate-10
	done_upgrade_rate = true
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

function draw_status()
	draw_shadow_text("Cash: "..cash, 160, 10, 10)
	draw_shadow_text("Quater: "..quater, 160, 18, 10)
	draw_shadow_text("Payroll: "..payroll*guard_count, 160, 26, 10)
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

function invest_button(id, cost, text, already_done)
	local r = {15, 25 + id*10, 140, 8}
	local afford = cash-cost >= 0 and not already_done
	if draw_button(r, text, afford) and afford then
		return true
	else
		return false
	end
end
--}}}
--{{{ UI
rect_invest_btn = {10, 120, 40, 8}

rect_buy_area = {10, 10, 150, 100}
rect_buy_guard_btn = {15, 25, 90, 8}
rect_buy_tower_btn = {15, 35, 90, 8}
rect_buy_back_btn = {15, 70, 30, 8}
rect_cancel_btn = {15, 120, 40, 8}

function ui_normal()
	draw_status()
	local press = draw_button(rect_invest_btn, "INVEST")

	if quater == 0 and guard_count <= 0 then
		draw_shadow_text("You need guards!", 10, 80, 6)
		draw_shadow_text("Click", 10, 88, 6)
		draw_shadow_text("INVEST", 42, 88, colorspin // 2)
	end

	if press then
		cb_ui = ui_invest
	end
end

function ui_invest()
	draw_rect(rect_buy_area)
	draw_shadow_text("Investors menu", 13, 13, 14)
	draw_status()

	if invest_button(0, 30, "GUARD ("..price_guard.." + "..payroll.."X)", false) then
		cb_ui = ui_place_guard
	end

	if invest_button(1, price_tower, "TOWER ("..price_tower..")", done_tower) then
		build_tower()
		cash_balance(-price_tower)
		cb_ui = ui_normal
	end

	if invest_button(2, price_upgrade_range, "UPGRADE RANGE ("..price_upgrade_range..")", done_upgrade_range) then
		cb_ui = ui_place_guard
		guard_upgrade_range()
		cash_balance(-price_upgrade_range)
		cb_ui = ui_normal
	end

	if invest_button(3, price_upgrade_rate, "UPGRADE FIRE RATE ("..price_upgrade_rate..")", done_upgrade_rate) then
		cb_ui = ui_place_guard
		guard_upgrade_rate()
		cash_balance(-price_upgrade_rate)
		cb_ui = ui_normal
	end

	if draw_button(rect_buy_back_btn, "Back") then
		cb_ui = ui_normal
	end
end

function ui_place_guard()
	draw_shadow_text("Place guard on top of building",
	13, 13, colorspin // 2)

	if mpress then
		local tile = tile_at(mx, my)
		if tile // 16 == 5 then
			local x = (mx // 8)*8
			local y = (my // 8)*8
			if actor_is_taken(x, y) then
			else
				guard_new(x, y)
				cash_balance(-price_guard)
				cb_ui = ui_normal
			end
		end
	end

	if draw_button(rect_cancel_btn, "Cancel") then
		cb_ui = ui_normal
	end
end
--}}}
--{{{ CASH
function cash_steal(amount)
	cash = cash-amount

	cash_check_balance()
end

function cash_balance(amount)
	cash = cash+amount
	cash_check_balance()
end

function cash_check_balance()
	if cash < 0 then
		go_init(quater)
	end
end

function cash_quaterly()
	sfx(2)
	cash = math.ceil(cash * 1.25)
	local salleries = guard_count*payroll
	cash_balance(-salleries)
	stats_payrolled = stats_payrolled+salleries
	quater = quater+1
end
--}}}
--{{{ MISC
function build_tower()
	local offset_a = {9, 7}
	local offset_b = {0, 20}
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

	done_tower = true
end
--}}}
--{{{ TIMER
-- This was added in the end =P of the coding part

function timer_new(ticks)
	return {
		duration=ticks,
		ttl=ticks,
	}
end

function timer_tick(timer)
	timer.ttl = timer.ttl-1
	if timer.ttl <= 0 then
		timer_restart(timer)
		return true
	else
		return false
	end
end

function timer_restart(timer)
	timer.ttl = timer.duration
end

function timer_restart_duration(timer, duration)
	timer.duration = duration
	timer.ttl = duration
end

--}}}
--{{{ MAIN GAME
--cash, mhold, mx, my, t, game_time, house, cb_ui

function main_init()
	-- Default settings
	cash = 300
	t = 0
	game_time = 0
	quater = 0
	house = {152, 72}
	cb_ui = nil
	actors = {}

	stats_kills = 0
	stats_payrolled = 0
	stats_thefts = 0

	guard_count = 0
	guard_range = 90
	guard_rate = 25

	done_tower = false
	done_upgrade_range = false
	done_upgrade_rate = false

	bandit_next = 500
	bandit_timer = 0
	bandit_waves = 0

	sfx(0)

	cb_ui = ui_normal
	--cb_ui = ui_invest
	--cb_ui = ui_place_guard

	main_cb = main_TIC
	sync(false)
end

function main_TIC()
	t = t+1
	game_time = game_time+1

	map(0, 0, 30, 17, 0, 0)

	if bandit_tic() then
		cash_quaterly()
	end

	tic_actors()
	lines_tic()
	cb_ui()
end
--}}}
--{{{ MAIN SPLASH
local countdown

splash_lines = {
	{"Bestfund inc.", 0, 10, 11},

	{"As a small bank owner you have all your", 0, 10, 15},
	{"capital in the best investment fund in", 0, 0, 15},
	{"the world. Each quater the fund grows by", 0, 0, 15},
	{"25%! Nice! However, all the bandits in", 0, 0, 15},
	{"the world knows about this.", 0, 0, 15},
	{"If a bandit reaches your house, you", 0, 5, 15},
	{"loose 100.", 0, 0, 15},

	{"[ PRESS MOUSE TO START ]", 0, 20, 14},
}

function splash_init()
	actors = {}

	countdown = timer_new(300)

	for i, l in ipairs(splash_lines) do
		l[2] = 120 - print(l[1], -200, -200, 0) // 2
	end

	sfx(6, 14, 200, 1)

	main_cb = splash_TIC
end

function splash_TIC()
	cls(7)

	if mpress then
		main_init()
	else

		local y = 0
		for i, l in ipairs(splash_lines) do
			y = y+l[3]
			draw_shadow_text(l[1], l[2], y, l[4])
			y = y+10
		end

		if timer_tick(countdown) then
			if guard_count < 4 then
				splash_rand_guard()
			end
		end
	end

	tic_actors()
end

function splash_rand_guard()
	guard_new(10 + math.random()*200, 100 + math.random()*15)
end
--}}}
--{{{ MAIN GAME OVER
function go_init(reached)
	sfx(4)
	go_quater = reached

	main_cb = go_TIC
end

function go_TIC()
	cls(7)

	draw_shadow_text("!!! GAME OVER !!!", 75, 20, 15)
	draw_shadow_text("Cash: ", 70, 40, 15)
	draw_shadow_text(cash, 101, 40, 6)
	draw_shadow_text("Quater: "..go_quater, 70, 48, 15)
	draw_shadow_text("Thefts: "..stats_thefts, 70, 60, 15)
	draw_shadow_text("Bandits stopped: "..stats_kills, 70, 68, 15)
	draw_shadow_text("Guard count: "..guard_count, 70, 76, 15)
	draw_shadow_text("Total salaries payed: "..stats_payrolled, 70, 94, 15)

	draw_shadow_text("[ PRESS MOUSE TO RESTART ]", 50, 120, colorspin // 2)

	if mpress then
		splash_init()
	end
end
--}}}
--{{{ MAIN

function init()
	splash_init()
	--main_init()
	--go_init(4)
end

function TIC()
	colorspin = (colorspin + 1) % 32

	local mfpress
	mx, my, mfpress = mouse()
	mpress = (mhold == false) and mfpress
	mhold = mfpress

	main_cb()
end

init()
--}}}
