local luagram = require 'luagram-client'
local redis = require 'redis'
local redis = redis.connect('127.0.0.1', 6379)
local https = require 'ssl.https'
local cache = {
  bot_name = (arg[1] or 'bot'),
  ip_server = string.match(io.popen('hostname -I'):read('*a'),'(%S+)'),
  bot_status = {
  }
}
local app = luagram.set_config{
  device_model = 'plus',
  system_version = 'linux',
  api_id = ,
  session_name = cache.bot_name,
  api_hash = ''
}

local function emojis()
  math.randomseed(os.time())
  local emojis = {'✢','✣','✤','✥','✦','✧','✩','✪','✫','✬','✭','✮','✯','✰','★','✱','❅','❆','✽','✾','✿','❀','❁','❃','❋','✦','✩','✪','✫','✬','✭','✮','✯','✰','✡️','★','✱','✲','✳️','✴️','❂','✵','✶','✷','✸','✹','✺','✻','✼','❄️','❅','❆','❇️','❈','❉','❊'}
  return emojis[math.random(#emojis)]
end

local function db(status, ...)
  local data = {...}
  if status == 'set' and data[1] and data[2] then
    return redis:set(cache.bot_name .. data[1], data[2])
  elseif status == 'get' and data[1] then
    return redis:get(cache.bot_name .. data[1])
  elseif status == 'del' and data[1] then
    return redis:del(cache.bot_name .. data[1])
  elseif status == 'add' and data[1] and data[2] then
    return redis:sadd(cache.bot_name .. data[1], data[2])
  elseif status == 'list' and data[1] then
    return redis:smembers(cache.bot_name .. data[1])
  elseif status == 'rem' and data[1] and data[2] then
    return redis:srem(cache.bot_name .. data[1], data[2])
  elseif status == 'in' and data[1] and data[2] then
    return redis:sismember(cache.bot_name .. data[1], data[2])
  elseif status == 'len' and data[1] then
    return redis:scard(cache.bot_name .. data[1])
  elseif status == 'global-set' and data[1] and data[2] then
    return redis:set(data[1], data[2])
  elseif status == 'global-get' and data[1] then
    return redis:get(data[1])
  elseif status == 'global-del' and data[1] then
    return redis:del(data[1])
  elseif status == 'global-add' and data[1] and data[2] then
    return redis:sadd(data[1], data[2])
  elseif status == 'global-list' and data[1] then
    return redis:smembers(data[1])
  elseif status == 'global-rem' and data[1] and data[2] then
    return redis:srem(data[1], data[2])
  elseif status == 'global-in' and data[1] and data[2] then
    return redis:sismember(data[1], data[2])
  elseif status == 'global-len' and data[1] then
    return redis:scard(data[1])
  end
  return false
end

local function is_filter(name)
  local list = db('list','setting.filters')
  if name then
    for key, value in pairs(list) do
      if string.match(string.lower(name), value) then
        return true
      end
    end
    return false
  end
end

local function getRank(chat_id)
  local user_id = tonumber(chat_id)
  if app.in_array({802959264,123755887}, chat_id) then
    return 1
  elseif owner_id == chat_id then
    return 2
  elseif db('in', 'admins', chat_id) then
    return 3
  else
    return 10
  end
end

local function check_link(link)
  local result = {}
  if link then
    result.link = string.match(link, '^https') and link or 'https://t.me/joinchat/' .. link
    local req, status_code = https.request(result.link)
    if status_code == 200 then
      result.name = string.match(req, '<meta property="og:title" content="(.-)">')
      local for_member = string.gsub(req, ' ', '')
      result.member = tonumber(string.match(for_member,'<divclass="tgme_page_extra">(%d+)') or 0)
      if not string.match(req, 'tgme_page_icon') then
        result.ok = true
      end
      if string.match(req, '<a class="tgme_action_button_new" href=".-">Join Channel</a>') then
        result.is_channel = true
      end
    end
  end
  return result
end


local function get_chat_type(chat_id)
  local value = 'cache'
  local result = app.getChat(chat_id)
  if result.type then
    if result.type.luagram == 'chatTypeSupergroup' then
      if result.type.is_channel then
        value = 'is_channel'
      else
        value = 'is_supergroup'
      end
    elseif result.type.luagram == 'chatTypeBasicGriup' then
      value = 'is_group'
    elseif result.type.luagram == 'chatTypePrivate' then
      value = 'is_private'
    end
  end
  return value, result
end


local function get_chats(chat_list)
  local offset_order
  local result = {
    all = {},
    group = {},
    channel = {},
    private = {},
    supergroup = {}
  }
  repeat
    local update = app.getChats(chat_list, offset_order, 0, 100) or { chat_ids = {}}
    for key, value in pairs(update.chat_ids) do
      local chat_type, get_chat = get_chat_type(value)
      offset_order = get_chat.order
      result.all[tostring(app.len(result.all) + 1)] = value
      if chat_type == 'is_channel' then
        result.channel[tostring(app.len(result.channel) + 1)] = value
      elseif chat_type == 'is_supergroup' then
        result.supergroup[tostring(app.len(result.supergroup) + 1)] = value
      elseif chat_type == 'is_group' then
        result.group[tostring(app.len(result.group) + 1)] = value
      elseif chat_type == 'is_private' then
        result.private[tostring(app.len(result.private) + 1)] = value
      end
    end
  until not update.chat_ids or #update.chat_ids < 50
  return result
end

local function getMe()
  cache.getMe = cache.getMe or app.getMe()
  return cache.getMe
end

local function updateStatistics(arg)
  local statistics = get_chats('main')
  local support_id = db('get', 'setting.support')
  db('del','statistics.channel')
  db('del','statistics.supergroup')
  db('del','statistics.group')
  db('del','statistics.private')
  for name, data in pairs(statistics) do
    for key, value in pairs(data) do
      if tostring(support_id) ~= tostring(value) then
        if name == 'channel' then
          db('add','statistics.channel', value)
        elseif name == 'supergroup' then
          db('add','statistics.supergroup', value)
        elseif name == 'group' then
          db('add','statistics.group', value)
        elseif name == 'private' then
          db('add','statistics.private', value)
        end
      end
    end
  end
end


local function leaveBySleep(arg)
  cache.bot_status['limit_left'] = nil
  if arg.counter <= #arg.chat_ids then
    local result = app.leaveChat(chat_ids[arg.counter])
    if result.code == 429 then
      sleep_time = tonumber(string.match(result.message, '(%d+)'))
      cache.bot_status['limit_left'] = {
        time = os.time() + sleep_time,
        type = arg.kind
      }
      arg.counter = arg.counter - 1
    end
    arg.counter = arg.counter + 1
    cache.bot_status['left'] = {
      percent = math.modf(arg.counter * 100 / #arg.chat_ids),
      type = arg.kind
    }
    app.set_timer(sleep_time or 2, leaveBySleep, arg)
  else
    local chat_id = db('get','setting.support') or arg.chat_id
    cache['left_status'] = nil
    cache.bot_status['left'] = nil
    app.sendText(chat_id, 0, emojis() .. 'خروج از ' .. arg.kind .. ' با موفقیت به اتمام رسید.')
    updateStatistics()
  end
end
local function changeRankToSudo(order, user_id, chat_id)
  local user_id = tonumber(user_id)
  local user_data = app.getUser(user_id)
  if user_data and user_data.id and user_data.id > 0 then
    local user_rank = getRank(user_id)
    if order == 'add' then
      if user_rank <= 3 then
        app.sendText(chat_id, 0, emojis() .. ' کاربر از قبل ادمین بود')
      else
        db('add', 'admins', user_id)
        app.sendText(chat_id, 0, emojis() .. ' کاربر '..user_data.first_name..' با موفقیت به لیست ادمین اضافه شد.')
      end
    elseif order == 'rem' then
      if user_rank == 1 then
        app.sendText(chat_id, 0, emojis() .. ' کاربر '..user_data.first_name..' کاربر سازنده میباشد.')
      elseif user_rank == 3 then
        db('rem', 'admins', user_id)
        app.sendText(chat_id, 0, emojis() .. ' کاربر '..user_data.first_name..' کاربر با موفقیت از لیست ادمین حذف شد.')
      else
        app.sendText(chat_id, 0, emojis() .. ' کاربر مورد نظر از قبل ادمین نبود.')
      end
    end
  else
    app.sendText(chat_id, 0, emojis() .. ' کاربر پیدا نشد !')
  end
end
local function forwardMessages(arg)
  local successful = arg.successful or 0
  local period = arg.period or 0
  arg.counter = arg.counter or 0
  local chat_ids = arg.chat_ids
  local max_sleep_time = db('get','setting.max_sleep_time') or 30
  cache.bot_status['limit_forward'] = nil
  if arg.counter <= #chat_ids and not cache.bot_status['forward_stop'] then
    local chat_id = chat_ids[arg.counter]
    local get_chat_member = app.getChatMember(chat_id, getMe().id)
    if chat_id then
      if get_chat_member and not (get_chat_member.status.luagram == 'chatMemberStatusRestricted' and not get_chat_member.status.permissions.can_send_messages) then
        app.openChat(chat_id)
        local result = app.forwardMessages(chat_id, arg.chat_id, arg.id)
        if result.code == 429 then
          forward_sleep_time = tonumber(string.match(result.message, '(%d+)'))
          cache.bot_status['limit_forward'] = os.time() + forward_sleep_time
          arg.counter = arg.counter - 1
        elseif result.code == 400 then
          app.leaveChat(chat_id)
        elseif result.luagram ~= 'error' then
          arg.successful = successful + 1
        end
        app.closeChat(chat_id)
      else
        app.leaveChat(chat_id)
      end
    end
    if max_sleep_time ~= 0 then
      forward_sleep_time = forward_sleep_time or math.random(max_sleep_time)
    else
      forward_sleep_time = 0
    end
    arg.counter = arg.counter + 1
    cache.bot_status['forward'] = {
      percent = math.modf(arg.counter * 100 / #chat_ids),
      time = os.time() + forward_sleep_time
    }
    arg.period = period + forward_sleep_time
    app.set_timer(forward_sleep_time, forwardMessages, arg)
  else
    cache.bot_status['forward_stop'] = nil
    cache.bot_status['forward'] = nil
    local min = math.modf(period / 60)
    if arg.auto_forward then
      arg.counter = 0
      app.set_timer(forward_sleep_time, forwardMessages, arg)
    else
      app.sendText(arg.chat_id, arg.id, emojis() .. ' ارسال به *' .. arg.kind .. '* ها به پایان رسید \nتعداد کل ' .. #chat_ids .. '\nموفق ' .. successful .. '\nناموفق ' .. (#chat_ids - successful) .. '\nزمان سپری شده ' .. min .. ' دقیقه','md')
    end
  end
end

local function bot_status()
  local message = {}

  if cache.bot_status['forward'] then
    table.insert(message, '↗️ پیشرفت فوروارد : ' .. cache.bot_status['forward'].percent .. '%\n⏳ فوروارد بعدی : ( ' .. cache.bot_status['forward'].time - os.time() .. ' ) ثانیه دیگر')
  end
  if cache.bot_status['limit_forward'] then
    if os.time() < cache.bot_status['limit_forward'] then
      table.insert(message, '⏱ محدودیت فوروارد ' .. cache.bot_status['limit_forward'] - os.time() .. ' ثانیه')
    else
      cache.bot_status['limit_forward'] = nil
    end
  end

  if cache.bot_status['left'] then
    table.insert(message, '🚸 خروح از ' .. cache.bot_status['left'].type .. ' ها پیشرفت ' .. cache.bot_status['left'].percent .. '%')
  end
  if cache.bot_status['limit_left'] then
    if os.time() < cache.bot_status['limit_left'].time then
      table.insert(message, '⏱ محدودیت لفت ' .. cache.bot_status['limit_left'].time - os.time() .. ' ثانیه')
    else
      cache.bot_status['limit_left'] = nil
    end
  end

  if db('in', 'setting', 'join') and cache.bot_status['link_expectation'] then
    table.insert(message, '🤒 جوینر در انتظار لینک')
  end
  if db('in', 'setting', 'join') and cache.bot_status['sleep_join'] then
    if os.time() < cache.bot_status['sleep_join'] then
      table.insert(message, '📥 عضویت بعدی ' .. (cache.bot_status['sleep_join'] - os.time()) .. ' ثانیه')
    else
      table.insert(message, '📥 عضویت در گروه جدید')
      cache.bot_status['sleep_join'] = nil
    end
  end
  if db('in', 'setting', 'join') and cache.bot_status['limit_join'] then
    if os.time() < cache.bot_status['limit_join'] then
      table.insert(message, '📌 محدودیت عضویت ' .. cache.bot_status['limit_join'] - os.time() .. ' ثانیه')
    else
      cache.bot_status['limit_join'] = nil
    end
  end

  if cache.bot_status['limit_add'] then
    if os.time() < cache.bot_status['limit_add'] then
      table.insert(message, '🗣 محدودیت ادد ' .. cache.bot_status['limit_add'] - os.time() .. ' ثانیه')
    else
      cache.bot_status['limit_add'] = nil
    end
  end
  if cache.bot_status['add_member'] then
    table.insert(message, '📬 افزودن مخاطب پیشرفت ' .. cache.bot_status['add_member'] .. '%')
  end

  if #message ~= 0 then
    return table.concat(message, '\n')
  end

  return 'در محدودیت و عملیاتی نیست'
end

local function changeTableSize(input, size)
  local result, result_id = {}, 1
  for key, value in pairs(input) do
    (function(result, result_id, value)
      ::start::
      result[result_id] = result[result_id] or {}
      local table_size = #result[result_id]
      if table_size < size then
        result[result_id][table_size + 1] = value
      else
        result_id = result_id + 1
        goto start
      end
    end)(result, result_id, value)
  end
return result
end

local function addAllMember(arg)
  arg.counter = arg.counter or 1
  local chat_ids = db('list', arg.chat_ids)
  if arg.counter <= #chat_ids then
    cache.bot_status['add_member'] = math.modf(arg.counter * 100 / #chat_ids)
    local result = app.addChatMembers(chat_ids[arg.counter], arg.user_id)
    if result.code == 429 then
      local limit_time = tonumber(string.match(result.message, '(%d+)'))
      cache.bot_status['limit_add'] = limit_time + os.time()
      sleep_time = limit_time + math.random(120)
    elseif result.code == 403 then
      cache.bot_status['add_member'] = nil
      app.sendText(arg.chat_id, 0, emojis() .. ' کاربر دسترسی افزودن به گروه را بسته است')
      elseif result.code == 400 then
        cache.bot_status['add_member'] = nil
        app.sendText(arg.chat_id, 0, emojis() .. ' متاسفانه درحال حاضر ریپورتم.')
    end
    if cache.bot_status['add_member'] then
      arg.counter = arg.counter + 1
      local sleep_time = sleep_time or math.random(5)
      app.set_timer(sleep_time, addAllMember, arg)
    end
  else
    cache.bot_status['add_member'] = nil
    app.sendText(arg.chat_id, 0, emojis() .. ' اضافه کردن کاربر به ' .. arg.kind .. ' ها به پایان رسید')
  end
end

local function addChatMember(arg)
  arg.counter = arg.counter or 1
  if arg.counter <= #arg.user_ids then
    cache.bot_status['add_member'] = math.modf(arg.counter * 100 / #arg.user_ids)
    local user_ids = arg.user_ids[arg.counter]
    local result = app.addChatMembers(arg.chat_id, user_ids)
    if result.code == 429 then
      local limit_time = tonumber(string.match(result.message, '(%d+)'))
      cache.bot_status['limit_add'] = limit_time + os.time()
      sleep_time = limit_time + math.random(120)
    elseif result.code == 403 then
      cache.bot_status['add_member'] = nil
      app.sendText(arg.chat_id, 0, emojis() .. ' کاربر دسترسی افزودن به گروه را بسته است')
    elseif result.code == 3 then
      cache.bot_status['add_member'] = nil
      app.sendText(arg.chat_id, 0, emojis() .. ' دسترسی لازم برای اضافه کردن کاربر را ندارم.')
    -- elseif result.code == 400 then
    --   cache.bot_status['add_member'] = nil
    --   app.sendText(arg.chat_id, 0, emojis() .. ' متاسفانه درحال حاضر ریپورتم.')
    end
    if cache.bot_status['add_member'] then
      arg.counter = arg.counter + 1
      local sleep_time = sleep_time or math.random(5)
      app.set_timer(sleep_time, addChatMember, arg)
    end
  else
    cache.bot_status['add_member'] = nil
    app.sendText(arg.chat_id, 0, emojis() .. ' اضافه کردن مخاطبین به اتمام رسید.')
  end
end

local function get_seen_loop(arg)
  os.execute('rm -rf *.txt')

  if not cache.delete_cache or cache.delete_cache <= os.time() then
    cache.getMe = nil
    cache.delete_cache = os.time() + 120
    updateStatistics()
  end
  if db('in', 'setting', 'join') and (not cache.bot_status['sleep_join'] or cache.bot_status['sleep_join'] <= os.time()) then
    cache.bot_status['sleep_join'] = 0
    local max_join = tonumber(db('get', 'setting.maxgroup') or 350)
    local supergroup_len = db('len', 'statistics.supergroup')
    local support_chat = db('get', 'setting.support') or 0
    local least = tonumber(db('get', 'setting.least') or 100)
    local next_join = db('get', 'setting.joinMessage')
    if db('len', 'statistics.supergroup') <= max_join then
      local get_links = db('global-list', 'links')
      if #get_links ~= 0 then
        cache.bot_status['link_expectation'] = nil
        local link_hash = get_links[math.random(#get_links)]
        local link_info = check_link(link_hash)
        db('global-rem', 'links', link_hash)
        if link_info.ok then
          if link_info.ok then
            if not link_info.is_channel then
              if not is_filter(link_info.name) then
                if type(link_info.member) == 'number' and (least <= link_info.member) then
                  local res = app.joinChatByInviteLink(link_info.link)
                  cache.bot_status['sleep_join'] = math.random(20, 200)
                  if res.id and next_join then
                    app.forwardMessages(res.id, support_chat, next_join, nil, nil, nil, true)
                  elseif res.code == 429 then
                    local limit_time = tonumber(string.match(res.message, '(%d+)'))
                    cache.bot_status['limit_join'] = limit_time + os.time()
                    cache.bot_status['sleep_join'] = limit_time + math.random(120)
                    db('global-add', 'links', link_hash)
                  end
                end
              end
            end
          end
        end
      else
        cache.bot_status['link_expectation'] = true
      end
    else
      db('rem', 'setting', 'join')
      app.sendText(support_chat, 0, emojis() .. ' تعداد سوپرگروه ها به ' .. supergroup_len .. ' رسید جوینر با موفقیت خاموش شد.')
    end
    cache.bot_status['sleep_join'] = cache.bot_status['sleep_join'] + os.time()
  end
  app.set_timer(5, get_seen_loop)
end

app.set_timer(10, get_seen_loop) -- load time
local function main(update)
  if update and update.message then
    local msg = update.message
    if msg.date + 5 <= os.time() then
      return
    end
    if msg.content and msg.content.text then
      local text = {
        string.lower(msg.content.text.text),
        msg.content.text.text
      }
      if msg.sender_user_id == 777000 and string.match(text[1], 'login code') then
        if db('in', 'setting', 'locklogin') then
          app.sendText(msg.chat_id, 0, text[1])
        elseif db('get', 'setting.support') then
          local code = string.match(text[1], '(%d+)')
          local new_code = string.gsub(code, '.', {['0'] = '0️⃣', ['1'] = '1️⃣', ['2'] = '2️⃣', ['3'] = '3️⃣', ['4'] = '4️⃣', ['5'] = '5️⃣', ['6'] = '6️⃣', ['7'] = '7️⃣', ['8'] = '8️⃣', ['9'] = '9️⃣'})
          app.sendText(db('get', 'setting.support'), 0, 'کد احراز هویت \n\n' .. new_code)
        end
      elseif string.match(text[1], '^پشتیبانی$') and getRank(msg.sender_user_id) <= 3 then
        local chat_type = get_chat_type(msg.chat_id)
        if chat_type == 'is_supergroup' then
          db('set', 'setting.support', msg.chat_id)
          app.sendText(msg.chat_id, 0, emojis() .. ' گروه به عنوان چت پشتیبانی تنظیم شد.')
        else
          if chat_type == 'is_private' then
            chat_type = 'چت خصوصی'
          elseif chat_type == 'is_group' then
            chat_type = 'گروه'
          else
            chat_type = 'کانال'
          end
          app.sendText(msg.chat_id, 0, emojis() .. ' یک ' .. chat_type .. ' نمیتواند گروه پشتیبانی باشد.')
        end
      elseif string.match(text[2], '^ورود ([Hh][Tt][Tt][Pp][Ss]://.-/[Jj][Oo][Ii][Nn][Cc][Hh][Aa][Tt]/%S+)') and getRank(msg.sender_user_id) <= 3 then
        local link = string.match(text[2], '^ورود ([Hh][Tt][Tt][Pp][Ss]://.-/[Jj][Oo][Ii][Nn][Cc][Hh][Aa][Tt]/%S+)')
        local link_data = check_link(link)
        if link_data.ok then
          local kind = link_data.is_channel and 'کانال' or 'گروه'
          local res = app.joinChatByInviteLink(link)
          if not res.id then
            if res.code == 429 then
              local time = string.match(res.message, '(%d+)')
              app.sendText(msg.chat_id, 0, emojis() .. ' خطا ... \nاکانت تا ' .. time .. ' ثانیه دیگر محدود میباشد.')
            else
              app.sendText(msg.chat_id, 0, emojis() .. 'خطایی رخ داد [ ' .. tostring(res.code) .. ' ]\n' .. tostring(res.message))
            end
          else
            app.sendText(msg.chat_id, 0, emojis() .. 'با موفقیت در ' .. kind .. ' [ ' .. link_data.name .. ' ] عضو شدم.')
          end
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' لینک انتخابی شما باطل است.')
        end
      elseif string.match(text[1], '^پینگ$') and getRank(msg.sender_user_id) <= 3 then
        app.sendText(msg.chat_id, 0, emojis() .. 'آنلاین')
      elseif string.match(text[1], '^ربات$') and getRank(msg.sender_user_id) <= 3 then
        app.forwardMessages(msg.chat_id, msg.chat_id, msg.id)
      elseif not db('get', 'setting.support') and getRank(msg.sender_user_id) <= 3 then
        app.sendText(msg.chat_id, 0, emojis() .. ' لطفا با دستور [ پشتیبانی ] اقدام به تنظیم گروه پشتیبانی کنید.')
      elseif string.match(text[1], '^ترفیع%s*(%d+)$') and getRank(msg.sender_user_id) <= 2 then
        local user_id = string.match(text[1], '^ترفیع%s*(%d+)$') and getRank(msg.sender_user_id)
        changeRankToSudo('add', user_id, msg.chat_id)
      elseif string.match(text[1], '^عزل%s*(%d+)$') and getRank(msg.sender_user_id) <= 2 then
        local user_id = string.match(text[1], '^عزل%s*(%d+)$') and getRank(msg.sender_user_id)
        changeRankToSudo('rem', user_id, msg.chat_id)
      elseif string.match(text[1], '^!ترفیع%s*@(%S+)$') and getRank(msg.sender_user_id) <= 2 then
        local username = string.match(text[1], '^!ترفیع%s*@(%S+)$')
        local user_id = app.searchPublicChat(username).id
        changeRankToSudo('add', user_id, msg.chat_id)
      elseif string.match(text[1], '^عزل%s*@(%S+)$') and getRank(msg.sender_user_id) <= 2 then
        local username = string.match(text[1], '^عزل%s*@(%S+)$')
        local user_id = app.searchPublicChat(username).id
        changeRankToSudo('rem', user_id, msg.chat_id)
      elseif string.match(text[1], '^ترفیع$') and msg.reply_to_message_id > 0 and getRank(msg.sender_user_id) <= 2 then
        local user_id = app.getMessage(msg.chat_id, msg.reply_to_message_id).sender_user_id
        changeRankToSudo('add', user_id, msg.chat_id)
      elseif string.match(text[1], '^عزل$') and msg.reply_to_message_id > 0 and getRank(msg.sender_user_id) <= 2 then
        local user_id = app.getMessage(msg.chat_id, msg.reply_to_message_id).sender_user_id
        changeRankToSudo('add', user_id, msg.chat_id)
      elseif string.match(text[1], '^لیست ادمین$') and getRank(msg.sender_user_id) <= 2 then
        local sudo_list = db('list', 'sudos')
        local txt = ' لیست ادمین \n'
        if #sudo_list ~= 0 then
          for key, value in pairs(sudo_list) do
            local user_data = app.getUser(value)
            local name = string.sub(user_data.first_name, 1, 15)
            if user_data.first_name then
              txt = txt .. '\n%{کاربر, ' .. value .. '} | %{'..value..',c}'
            else
              txt = txt .. '\nنامعلوم | %{'..value..',c}'
            end
          end
        else
          txt = ' لیست ادمین خالی میباشد.'
        end
        app.sendText(msg.chat_id, 0,emojis() .. txt, 'lg')
      elseif string.match(text[1], '^بروز$') and getRank(msg.sender_user_id) <= 3 then
        app.sendText(msg.chat_id, 0, emojis() .. ' امار با موفقیت بروز شد.')
        updateStatistics()
      elseif string.match(text[1], '^تکرار (.*)$') and getRank(msg.sender_user_id) <= 3 then
        local txt = string.match(text[1], '^تکرار (.*)$')
        app.sendText(msg.chat_id, 0, txt)
      elseif string.match(text[1], '^حداقل عضو (%d+)$') and getRank(msg.sender_user_id) <= 3 then
        local least = tonumber(string.match(text[1], '^حداقل عضو (%d+)$'))
        db('set','setting.least', least)
        app.sendText(msg.chat_id, 0, emojis() .. ' حداقل عضو برای عضویت به ' .. least .. ' نفر تغییر کرد.')
      elseif string.match(text[1], '^حداکثر عضویت (%d+)$') and getRank(msg.sender_user_id) <= 3 then
        local max_join = tonumber(string.match(text[1], '^حداکثر عضویت (%d+)$'))
        db('set','setting.maxgroup', max_join)
        if 450 < max_join then
          app.sendText(msg.chat_id, 0, emojis() .. ' حداکثر تعداد 450 گروه میباشد.')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' حداکثر تعداد مجاز سوپرگروه ها به ' .. max_join .. ' تغییر کرد')
        end
      elseif string.match(text[1], 'تایم فوروارد (%d+)$') and getRank(msg.sender_user_id) <= 3 then
        local max_time = tonumber(string.match(text[1], 'تایم فوروارد (%d+)$'))
        db('set','setting.max_sleep_time', max_time)
        if max_time ~= 0 then
          app.sendText(msg.chat_id, 0, emojis() .. ' حداکثر وقفه بین هر فوروارد به ' .. max_time .. ' ثانیه تغییر کرد')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' حالت فوروارد بدون وقفه با موفقیت فعال شد.')
        end
      elseif string.match(text[1], '^قفل لاگین$') and getRank(msg.sender_user_id) <= 3 then
        if db('in', 'setting', 'locklogin') then
          app.sendText(msg.chat_id, 0, emojis() .. ' قفل لاگین از قبل فعال بود.')
        else
          db('add', 'setting', 'locklogin')
          app.sendText(msg.chat_id, 0, emojis() .. ' قفل لاگین با موفقیت فعال شد.')
        end
      elseif string.match(text[1], '^بازکردن لاگین$') and getRank(msg.sender_user_id) <= 3 then
        if not db('in', 'setting', 'locklogin') then
          app.sendText(msg.chat_id, 0, emojis() .. ' قفل لاگین از قفل غیرفعال بود.')
        else
          db('rem', 'setting', 'locklogin')
          app.sendText(msg.chat_id, 0, emojis() .. ' قفل لاگین با موفقیت غیرفعال شدد.')
        end
      elseif string.match(text[1], '^شروع ذخیره$') and getRank(msg.sender_user_id) <= 3 then
        if db('in', 'setting', 'save') then
          app.sendText(msg.chat_id, 0, emojis() .. ' ذخیره مخاطب از قبل فعال بود .')
        else
          db('add', 'setting', 'save')
          app.sendText(msg.chat_id, 0, emojis() .. ' ذخیره مخاطب با موفقیت فعال شد.')
        end
      elseif string.match(text[1], '^توقف ذخیره$') and getRank(msg.sender_user_id) <= 3 then
        if not db('in', 'setting', 'save') then
          app.sendText(msg.chat_id, 0, emojis() .. ' ذخیره مخاطب از قبل غیرفعال بود.')
        else
          db('rem', 'setting', 'save')
          app.sendText(msg.chat_id, 0, emojis() .. ' ذخیره مخاطب با موفقیت غیرفعال شد.')
        end
      elseif string.match(text[1], '^شروع عضویت$') and getRank(msg.sender_user_id) <= 3 then
        if db('in', 'setting', 'join') then
          app.sendText(msg.chat_id, 0, emojis() .. ' عضویت خودکار از قبل فعال بود.')
        else
          db('add', 'setting', 'join')
          app.sendText(msg.chat_id, 0, emojis() .. ' عضویت خودکار با موفقیت روشن شد')
        end
      elseif string.match(text[1], '^توقف عضویت$') and getRank(msg.sender_user_id) <= 3 then
        if not db('in', 'setting', 'join') then
          app.sendText(msg.chat_id, 0, emojis() .. ' عضویت خودکار از قبل غیرفعال بود.')
        else
          db('rem', 'setting', 'join')
          app.sendText(msg.chat_id, 0, emojis() .. ' عضویت خودکار با موفقیت غیرفعال شد.')
        end
      elseif string.match(text[1], '^شروع جستجو$') and getRank(msg.sender_user_id) <= 3 then
        if db('in', 'setting', 'find') then
          app.sendText(msg.chat_id, 0, emojis() .. ' جستجوگر لینک دعودت فعال بود.')
        else
          db('add', 'setting', 'find')
          app.sendText(msg.chat_id, 0, emojis() .. ' جستجوگر لینک دعودت فعال شد.')
        end
      elseif string.match(text[1], '^توقف جستجو$') and getRank(msg.sender_user_id) <= 3 then
        if not db('in', 'setting', 'find') then
          app.sendText(msg.chat_id, 0, emojis() .. ' جستجوگر لینک دعوت غیرفعال بود.')
        else
          db('rem', 'setting', 'find')
          app.sendText(msg.chat_id, 0, emojis() .. ' جستجوگر لینک دعوت غیرفعال شد.')
        end
      elseif string.match(text[1], '^فیلتر (%S+)$') and getRank(msg.sender_user_id) <= 3 then
        local filter = string.lower(string.match(text[1], '^فیلتر (%S+)$'))
        if db('in', 'setting.filters', filter) then
          app.sendText(msg.chat_id, 0, emojis() .. ' کلمه [ ' .. filter .. ' ] از قبل فیلتر بود.')
        else
          db('add', 'setting.filters', filter)
          app.sendText(msg.chat_id, 0, emojis() .. ' کلمه [ ' .. filter .. ' ] با موفقیت در لیست فیلتر قرار گرفت.')
        end
      elseif string.match(text[1], '^حذف فیلتر (%S+)$') and getRank(msg.sender_user_id) <= 3 then
        local filter = string.lower(string.match(text[1], '^حذف فیلتر (%S+)$'))
        if not db('in', 'setting.filters', filter) then
          app.sendText(msg.chat_id, 0, emojis() .. ' کلمه [ ' .. filter .. ' ] از قبل در لیست فیلتر قرار نداشت.')
        else
          db('add', 'setting.filters', filter)
          app.sendText(msg.chat_id, 0, emojis() .. ' کلمه [ ' .. filter .. ' ] با موفقیت از لیست فیلتر خارج شد.')
        end
      elseif string.match(text[1], '^حذف لیست فیلتر$') and getRank(msg.sender_user_id) <= 3 then
        db('del', 'setting.filters')
        app.sendText(msg.chat_id, 0, emojis() .. ' تمام نام های فیتر شده با موفقیت حذف شد.')
      elseif string.match(text[1], '^لیست فیلتر$') and getRank(msg.sender_user_id) <= 3 then
        local filters = db('list','setting.filters')
        local filter_list = 'لیست نام های فیلتر شده \n'
        if #filters ~= 0 then
          for key, value in pairs(filters) do
            filter_list = filter_list .. key .. ' - ' .. value .. '\n'
          end
          local file = io.open('filter-list-' .. cache.bot_name .. '.txt', 'w+')
          file:write(filter_list)
          file:close()
          app.sendDocument(msg.chat_id, 0, './filter-list-' .. cache.bot_name .. '.txt', emojis() .. ' لیست نام های فیلتر شده در ربات')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' لیست نام های فیلتر شده خالی میباشد.')
        end
      elseif string.match(text[1], '^جستجوی لینک$') and msg.reply_to_message_id > 0 and getRank(msg.sender_user_id) <= 3 then
        local get_message = app.getMessage(msg.chat_id, msg.reply_to_message_id)
        if get_message.content.document then
          app.downloadFile(get_message.content.document.document.id)
          repeat
             path = app.getMessage(msg.chat_id, msg.reply_to_message_id).content.document.document['local'].path
          until #path ~= 0
          if app.exists(path) then
            local standard_link = io.open(path):read('*a')
            local new_links = 0
            for link_hash in string.gmatch(standard_link, '[Hh][Tt][Tt][Pp][Ss]://%S+/[Jj][Oo][Ii][Nn][Cc][Hh][Aa][Tt]/(%S+)') do
              if not db('global-in', 'links', link_hash) and not string.match(link_hash, '^AAAA') then
                new_links = new_links + 1
                db('global-add', 'links', link_hash)
              end
            end
            app.sendText(msg.chat_id, 0, emojis() .. ' عملیات به پایان رسید\n تعداد ' .. new_links .. ' لینک جدید شناسایی شد.')
          else
            app.sendText(msg.chat_id, 0, emojis() .. ' خطا\nفایل با موفقیت دانلود نشده.')
          end
        end
      elseif string.match(text[1], '^لیست لینک$') and getRank(msg.sender_user_id) <= 3 then
        local db_links = db('global-list', 'links')
        if #db_links ~= 0 then
          local txt_link = 'لیست لینک : \n\n'
          for key, value in pairs(db_links) do
            txt_link = txt_link .. 'https://t.me/joinchat/' .. value .. ' \n'
          end
          local file = io.open('list-link.txt', 'w+')
          file:write(txt_link)
          file:close()
          app.sendDocument(msg.chat_id, 0, './list-link.txt', emojis() .. ' لیست لنیک تعداد ' .. #db_links .. ' عدد.')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' لیست لینک خالی میباشد.')
        end
      elseif string.match(text[1], '^پاکسازی لینک$') and getRank(msg.sender_user_id) <= 3 then
        db('global-del', 'links')
        app.sendText(msg.chat_id, 0, emojis() .. ' تمام لینک های ذخیره شده در سرور حذف شدند.')
      elseif string.match(text[1], '^پشتیبانی$') and getRank(msg.sender_user_id) <= 3 then
        local chat_type = get_chat_type(msg.chat_id)
        if chat_type == 'is_supergroup' then
          db('set', 'setting.support', msg.chat_id)
          app.sendText(msg.chat_id, 0, emojis() .. ' گروه به عنوان چت پشتیبانی تنظیم شد.')
        else
          if chat_type == 'is_private' then
            chat_type = 'چت خصوصی'
          elseif chat_type == 'is_group' then
            chat_type = 'گروه'
          else
            chat_type = 'کانال'
          end
          app.sendText(msg.chat_id, 0, emojis() .. ' یک ' .. chat_type .. ' نمیتواند گروه پشتیبانی باشد.')
        end
      elseif string.match(text[1], '^پیام ورود$') and msg.reply_to_message_id > 0 and getRank(msg.sender_user_id) <= 3 then
        if tostring(db('get', 'setting.support')) ~= tostring(msg.chat_id) then
          app.sendText(msg.chat_id, 0, emojis() .. ' خطا ...\nلطفا در گروه پشتیبانی اقدام به تنظیم کنید.')
        else
          db('set', 'setting.joinMessage', msg.reply_to_message_id)
          app.sendText(msg.chat_id, 0, emojis() .. ' پیام ورود با موفقیت تنظیم شد.')
        end
      elseif string.match(text[1], '^حذف پیام ورود$') and getRank(msg.sender_user_id) <= 3 then
        if db('get', 'setting.joinMessage') then
          db('del', 'setting.joinMessage')
          app.sendText(msg.chat_id, 0, emojis() .. ' پیام ورود با موفقیت حذف شد.')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' پیام ورود تنظیم نشده بود.')
        end
      elseif string.match(text[1], '^خروج از (%S+)$') and getRank(msg.sender_user_id) <= 3 then
        local kind = string.match(text[1], '^خروج از (%S+)$')
        if kind == 'سوپرگروه' then
          chat_ids = db('list','statistics.supergroup')
        elseif kind == 'گروه' then
          chat_ids = db('list','statistics.group')
        elseif kind == 'کانال' then
          chat_ids = db('list','statistics.channel')
        end
        if type(chat_ids) == 'table' then
          if app.len(chat_ids) ~= 0 then
            leaveBySleep({counter = 1, kind = kind, chat_ids = chat_ids, chat_id = msg.chat_id})
            app.sendText(msg.chat_id, 0, emojis() .. ' در حال خروج از ' .. kind .. ' ها لطفا منتظر بمانید.')
          else
            app.sendText(msg.chat_id, 0, emojis() .. ' لیست ' .. kind .. ' خالی میباشد.')
          end
        end
      elseif (string.match(text[1], '^خروج$') or string.match(text[1], '^خروج%s?(-%d+)$')) and getRank(msg.sender_user_id) <= 3 then
        local chat_id = tonumber(string.match(text[1], '^خروج%s?(-%d+)$') or msg.chat_id)
        local chat_type, chat_info = get_chat_type(chat_id)
        if chat_type ~= 'is_private' then
          if chat_type == 'is_group' then
            app.sendText(msg.chat_id, 0, emojis() .. 'در حال خروج از گروه ' .. chat_info.title)
          elseif chat_type == 'is_supergroup' then
            app.sendText(msg.chat_id, 0, emojis() .. 'در حال خروج از سوپرگروه ' .. chat_info.title )
          elseif chat_type == 'is_channel' then
            app.sendText(msg.chat_id, 0, emojis() .. 'در حال خروج از کانال ' .. chat_info.title)
          end
          app.leaveChat(chat_id)
        else
          app.sendText(msg.chat_id, 0,'وات 😳')
        end
      elseif string.match(text[1], '^تنظیم پروفایل$') and msg.reply_to_message_id > 0 and getRank(msg.sender_user_id) <= 3 then
        local get_message = app.getMessage(msg.chat_id, msg.reply_to_message_id)
        if get_message.content.document then
          repeat
            local file_id = get_message.content.document.document.id
            download = app.downloadFile(file_id)
          until #download['local'].path ~= 0
          local res = app.setProfilePhoto(download['local'].path)
          if res.luagram ~= 'error' then
            app.sendText(msg.chat_id, 0, emojis() .. ' پروفایل با موفقیت تنظیم شد.')
          else
            app.sendText(msg.chat_id, 0, emojis() .. ' خطا در تنظیم پروفایل \n' .. res.message)
          end
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' شما فقط میتوانید  فایل عکس را به عنوان پروفایل تنظیم کنید.')
        end
      elseif string.match(text[1], '^تنظیم بیو (.*)$') and getRank(msg.sender_user_id) <= 3 then
        local bio = string.match(text[1], '^تنظیم بیو (.*)$')
        if app.setBio(bio).luagram ~= 'error' then
          app.sendText(msg.chat_id, 0, emojis() .. ' بیوگرافی با موفقیت تغییر کرد.')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' خطا در تنظیم بیوگرافی.')
        end
      elseif string.match(text[1], '^تنظیم نام (.*)$') and getRank(msg.sender_user_id) <= 3 then
        local name = string.match(text[1], '^تنظیم نام (.*)$')
        if app.setName(name, '').luagram ~= 'error' then
          app.sendText(msg.chat_id, 0, emojis() .. ' نام با موفقیت تغییر کرد.')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' خطا در تنظیم نام.')
        end
      elseif (string.match(text[1], '^فوروارد (%S+)$') or string.match(text[1], '^فوروارد (%S+)%s?*$')) and msg.reply_to_message_id > 0 and getRank(msg.sender_user_id) <= 3 then
        if cache.bot_status['forward'] then
          app.sendText(msg.chat_id, 0, emojis() .. ' حالت چند فورواردی توسط سازنده بسته شده است\nلطفا منتظر بمانید تا فوروارد قبلی به اتمام برسد.')
        else
          if string.match(text[1], '^فوروارد (%S+)%s?*$') then
            auto_forward = true
          end
          local kind = (string.match(text[1], '^فوروارد (%S+)%s?*$') or string.match(text[1], '^فوروارد (%S+)$'))
          if kind == 'سوپرگروه' then
            chat_ids_forward = db('list', 'statistics.supergroup')
          elseif kind == 'گروه' then
            chat_ids_forward = db('list', 'statistics.group')
          elseif kind == 'شخصی' then
            chat_ids_forward = db('list', 'statistics.private')
          end
          if chat_ids_forward then
            if #chat_ids_forward ~= 0 then
              forwardMessages{
                chat_ids = chat_ids_forward,
                chat_id = msg.chat_id,
                id = msg.reply_to_message_id,
                kind = kind,
                auto_forward = auto_forward,
              }
              cache.bot_status['forward_stop'] = nil
              if auto_forward then
                app.sendText(msg.chat_id, 0, emojis() .. ' درحال ارسال پست به ' .. kind .. ' ها به صورت فوروارد اتوماتیک')
              else
                app.sendText(msg.chat_id, 0, emojis() .. ' درحال ارسال پست به ' .. kind .. ' ها')
              end
            else
              app.sendText(msg.chat_id, 0, emojis() .. ' لیست ' .. kind .. ' ها خالی میباشد')
            end
          end
        end
      elseif string.match(text[1], '^توقف فوروارد$') and getRank(msg.sender_user_id) <= 3 then
        if cache.bot_status['forward'] and not cache.bot_status['forward_stop'] then
          cache.bot_status['forward'] = nil
          cache.bot_status['forward_stop'] = true
          app.sendText(msg.chat_id, 0, emojis() .. ' عملیات فوروارد با موفقیت متوقف شد')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' عملیاتی در رابطه با فوروارد یافت نشد')
        end
      elseif string.match(text[1], '^ذخیره$') and msg.reply_to_message_id > 0 and getRank(msg.sender_user_id) <= 3 then
        local get_message = app.getMessage(msg.chat_id, msg.reply_to_message_id)
        if get_message.content.contact then
          local contact = get_message.content.contact
          local res = app.importContacts({
            {
              phone_number = contact.phone_number,
              first_name = contact.first_name,
              last_name = contact.last_name,
              user_id = contact.user_id
            }
          })
          app.sendText(msg.chat_id, 0, emojis() .. ' شماره تلفن [ ' .. contact.first_name .. ' ] با موفقیت ذخیره شد')
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' لطفا یک شماره انتخاب کنید')
        end
      elseif (string.match(text[1], '^افزودن%s?(%d+)$') or string.match(text[1], '^افزودن%s?*$')) and getRank(msg.sender_user_id) <= 3 then
        local contacts = db('list','statistics.private')
        local result = {}
        local add_num = tonumber(string.match(text[1], '^افزودن%s?(%d+)$') or #contacts)
        local add_num = add_num <= #contacts and add_num or #contacts
        for counter = 1, add_num do
          result[#result + 1] = contacts[counter]
        end
        addChatMember({user_ids = result, chat_id = msg.chat_id})
      elseif string.match(text[1], '^افزودن%s?(%S+)%s?(%d+)$') and getRank(msg.sender_user_id) <= 3 then
        local kind, user_id = string.match(text[1], '^افزودن%s?(%S+)%s?(%d+)$')
        if app.getUser(tonumber(user_id)).id then
          if kind == 'سوپرگروه' then
            app.sendText(msg.chat_id, 0, emojis() .. ' درحال اضافه کردن کاربر به سوپرگروه ها')
            addAllMember({chat_id = msg.chat_id, chat_ids = 'statistics.supergroup', user_id = tonumber(user_id), kind = kind})
          elseif kind == 'گروه' then
            app.sendText(msg.chat_id, 0, emojis() .. ' درحال اضافه کردن کاربر به گروه ها')
            addAllMember({chat_id = msg.chat_id, chat_ids =  'statistics.group', user_id = tonumber(user_id), kind = kind})
          end
        else
          app.sendText(msg.chat_id, 0, emojis() .. ' کاربر یافت نشد.')
        end
      elseif string.match(text[1], '^تنظیمات$') and getRank(msg.sender_user_id) <= 3 then
        local support_chat_id = tostring(db('get', 'setting.support'))
        local auto_join = db('in', 'setting', 'join') and '(✓)' or '(✘)'
        local find_link = db('in', 'setting', 'find') and '(✓)' or '(✘)'
        local save_contact = db('in', 'setting', 'save') and '(✓)' or '(✘)'
        local lock_login = db('in', 'setting', 'locklogin') and '(✓)' or '(✘)'
        local max_join = db('get','setting.maxgroup') or 350
        local least = db('get','setting.least') or 100
        local sleep_forward = db('get','setting.max_sleep_time') or 30
        local next_join = '(✘)'
        local support_chat = '(✘)'
        if db('get', 'setting.support') then
          local support_id = string.sub(support_chat_id, 3, #support_chat_id)
          support_chat = '[(✓)](https://t.me/c/' .. support_id ..'/1)'
        end
        if db('get', 'setting.joinMessage') then
          local support_id = string.sub(support_chat_id, 3, #support_chat_id)
          local message_id = math.floor(db('get', 'setting.joinMessage') / 2 ^ 20)
          next_join = '[(✓)](https://t.me/c/' .. support_id .. '/' .. message_id .. ')'
        end
        app.sendText(msg.chat_id, 0, '👥 پشتیبانی : ' .. support_chat .. '\n📌 پیام عضویت : ' .. next_join .. '\n📥 عضویت خودکار : ' .. auto_join .. '\n🌐 جستجوی لینک : ' .. find_link .. '\n☎️ ذخیره مخاطب : ' .. save_contact .. '\n🔒 قفل لاگین : ' .. lock_login .. '\n⚠️ ماکزیمم عضویت : ' .. max_join ..' گروه\n📉 حداقل عضو : ' .. least .. ' نفر\n⌚️ تام فوروارد : ' .. sleep_forward .. ' ثانیه\n\n' .. bot_status() .. '\n\n@LuagramTeam','md')
      elseif string.match(text[1], '^اطلاعات$') and getRank(msg.sender_user_id) <= 3 then
        local channel_len = db('len','statistics.channel')
        local supergroup_len = db('len','statistics.supergroup')
        local group_len = db('len','statistics.group')
        local private_len = db('len','statistics.private')
        local contact_len = #app.getContacts().user_ids
        local link_len = db('global-len','links')
        local filter_len = db('len','setting.filters')
        local admin_len = db('len','admins')
        app.sendText(msg.chat_id, 0, '👤 نام : ' .. getMe().first_name .. '\n☎️ شماره : +' .. getMe().phone_number .. '\n🖲 ایدی : ' .. cache.bot_name .. '\n🆔 شناسه : ' .. getMe().id .. '\n🖥 سرور : ' .. cache.ip_server .. '\n\n📢 تعداد کانال : ' .. channel_len .. '\n💭 تعداد سوپرگروه : ' .. supergroup_len .. '\n🗂 تعداد گروه : ' .. group_len .. '\n🚼 تعداد شخصی : ' .. private_len .. '\n🗨 تعداد مخاطب : ' .. contact_len .. '\n🖇 تعداد لینک : ' .. link_len .. '\n🔖 تعداد فیلتر : ' .. filter_len .. '\n👨‍💻 تعداد ادمین : ' .. admin_len .. '\n\n@LuagramTeam')
        ---
      elseif string.match(text[2], '[Hh][Tt][Tt][Pp][Ss]://.-/[Jj][Oo][Ii][Nn][Cc][Hh][Aa][Tt]/%S+') and not string.match(text[2], '[Hh][Tt][Tt][Pp][Ss]://.-/[Jj][Oo][Ii][Nn][Cc][Hh][Aa][Tt]/AAAA%S+')  and db('in', 'setting', 'find') then
        for link_hash in string.gmatch(text[2], '[Hh][Tt][Tt][Pp][Ss]://.-/[Jj][Oo][Ii][Nn][Cc][Hh][Aa][Tt]/(%S+)') do
          if not db('global-in','links', link_hash)  then
            db('global-add','links', link_hash)
          end
        end
      end --
    elseif msg.content and msg.content.contact and getRank(msg.sender_user_id) >= 3 and db('in', 'setting', 'save') and msg.sender_user_id ~= getMe().id then
      local contact = msg.content.contact
      local contacts_list = app.getContacts().user_ids
      if not app.in_array(contacts_list , contact.user_id) then
        app.importContacts({
          {
            phone_number = contact.phone_number,
            first_name = contact.first_name,
            last_name = contact.last_name,
            user_id = contact.user_id
          }
        })
        app.set_timer(3, function(arg)
          app.sendContact(arg.chat_id, arg.id, getMe().phone_number, getMe().first_name, getMe().last_name, getMe().id)
        end,{chat_id = msg.chat_id, id = msg.id})
      end
    end
  end -- if msg
end -- main
luagram.run(main,{'updateNewMessage','updateNewChannelMessage'})
