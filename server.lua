local ESX
if GetResourceState('es_extended') ~= 'missing' then
  pcall(function()
    ESX = exports['es_extended']:getSharedObject()
  end)
  if not ESX then
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
  end
end

local function usingOx()
  local state = GetResourceState('oxmysql')
  return state == 'started' or state == 'starting'
end

local function dbExecute(query, params, cb)
  if usingOx() then
    exports.oxmysql:execute(query, params or {}, function(result)
      if cb then cb(result) end
    end)
  else
    if MySQL and MySQL.Async and MySQL.Async.execute then
      MySQL.Async.execute(query, params or {}, cb)
    else
      if cb then cb(nil) end
    end
  end
end

local function dbFetchAll(query, params, cb)
  if usingOx() then
    exports.oxmysql:execute(query, params or {}, function(result)
      cb(result or {})
    end)
  else
    if MySQL and MySQL.Async and MySQL.Async.fetchAll then
      MySQL.Async.fetchAll(query, params or {}, function(result)
        cb(result or {})
      end)
    else
      cb({})
    end
  end
end

local function ensureTable()
  dbExecute([[CREATE TABLE IF NOT EXISTS `fearx_multijobs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `job` VARCHAR(64) NOT NULL,
    `grade` INT NOT NULL DEFAULT 0,
    `label` VARCHAR(64) DEFAULT NULL,
    `grade_label` VARCHAR(64) DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_user_job` (`identifier`, `job`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

CreateThread(function()
  ensureTable()
  dbExecute([[INSERT IGNORE INTO fearx_multijobs (identifier, job, grade, label, grade_label)
    SELECT u.identifier, u.job, u.job_grade, j.label, g.label
    FROM users u
    LEFT JOIN jobs j ON j.name COLLATE utf8mb4_general_ci = u.job COLLATE utf8mb4_general_ci
    LEFT JOIN job_grades g ON g.job_name COLLATE utf8mb4_general_ci = u.job COLLATE utf8mb4_general_ci AND g.grade = u.job_grade
    WHERE u.job IS NOT NULL AND u.job <> ''
  ]])
end)

local function getIdentifier(src)
  local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src)
  if xPlayer and xPlayer.getIdentifier then return xPlayer.getIdentifier() end
  if xPlayer and xPlayer.identifier then return xPlayer.identifier end
  return nil
end

local function addJobForIdentifier(identifier, job, grade, label, grade_label)
  if not identifier or not job then return end
  local function upsert(jl, gl)
    dbExecute('INSERT INTO fearx_multijobs (`identifier`,`job`,`grade`,`label`,`grade_label`) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE `grade`=VALUES(`grade`), `label`=VALUES(`label`), `grade_label`=VALUES(`grade_label`)', { identifier, job, grade or 0, jl, gl })
  end
  if not label then
    dbFetchAll('SELECT j.label AS job_label, g.label AS grade_label FROM jobs j LEFT JOIN job_grades g ON g.job_name COLLATE utf8mb4_general_ci = j.name COLLATE utf8mb4_general_ci AND g.grade = ? WHERE j.name COLLATE utf8mb4_general_ci = ?', { grade or 0, job }, function(rows)
      local jl = rows[1] and rows[1].job_label or label
      local gl = rows[1] and rows[1].grade_label or grade_label
      upsert(jl, gl)
    end)
  else
    upsert(label, grade_label)
  end
end

RegisterNetEvent('fearx-multijob:addJob', function(job, grade, label, grade_label)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier or not job then return end
  addJobForIdentifier(identifier, job, tonumber(grade or 0) or 0, label, grade_label)
end)

RegisterNetEvent('fearx-multijob:setJob', function(job, grade)
  local src = source
  if not ESX then return end
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer or not job then return end
  local g = tonumber(grade or 0) or 0
  addJobForIdentifier(xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier, job, g)
  xPlayer.setJob(job, g)
end)

RegisterNetEvent('fearx-multijob:removeJob', function(job)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier or not job then return end
  dbExecute('DELETE FROM fearx_multijobs WHERE identifier COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci AND job COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci', { identifier, job })
end)

RegisterCommand('removejob', function(src, args)
  local target = tonumber(args[1])
  local job = args[2]
  if not target or not job then return end
  local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(target)
  if not xPlayer then return end
  local identifier = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
  if not identifier then return end
  dbExecute('DELETE FROM fearx_multijobs WHERE identifier COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci AND job COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci', { identifier, job })
end, false)

ESX.RegisterServerCallback('fearx-multijob:getJobs', function(src, cb)
  local identifier = getIdentifier(src)
  if not identifier then cb({}, nil); return end
  local xPlayer = ESX.GetPlayerFromId(src)
  local current = nil
  local currentGrade = 0
  if xPlayer and xPlayer.getJob then
    local j = xPlayer.getJob()
    current = j and j.name or nil
    currentGrade = (j and j.grade) or 0
  elseif xPlayer and xPlayer.job then
    current = xPlayer.job.name
    currentGrade = xPlayer.job.grade or 0
  end
  
  dbFetchAll([[SELECT f.job, f.grade, j.label AS label, g.label AS grade_label
               FROM fearx_multijobs f
               LEFT JOIN jobs j ON j.name COLLATE utf8mb4_general_ci = f.job COLLATE utf8mb4_general_ci
               LEFT JOIN job_grades g ON g.job_name COLLATE utf8mb4_general_ci = f.job COLLATE utf8mb4_general_ci AND g.grade = f.grade
               WHERE f.identifier = ?]], { identifier }, function(rows)
    local jobs = {}
    for i=1, #rows do
      local r = rows[i]
      jobs[#jobs+1] = {
        job = r.job,
        grade = tonumber(r.grade) or 0,
        label = r.label,
        grade_label = r.grade_label
      }
    end
    cb(jobs, current)
  end)
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
  if not xPlayer then return end
  local identifier = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
  if not identifier then return end
  local job = (xPlayer.getJob and xPlayer.getJob() or xPlayer.job) or {}
  if job and job.name then
    addJobForIdentifier(identifier, job.name, tonumber(job.grade or 0) or 0, job.label, job.grade_label or job.gradeLabel)
  end
end)

AddEventHandler('esx:setJob', function(playerId, job, lastJob)
  local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(playerId)
  if not xPlayer or not job or not job.name then return end
  local identifier = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
  if not identifier then return end
  local grade = tonumber(job.grade or 0) or 0
  addJobForIdentifier(identifier, job.name, grade, job.label, job.grade_label or job.gradeLabel)
end)
