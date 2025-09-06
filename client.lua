local ESX
pcall(function()
  ESX = exports['es_extended']:getSharedObject()
end)
if not ESX then
  TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
end

local isOpen = false

RegisterCommand(Config.Command, function()
  if isOpen then return end
  isOpen = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', title = Config.Title })
end, false)

RegisterNUICallback('close', function(_, cb)
  isOpen = false
  SetNuiFocus(false, false)
  cb({ ok = true })
end)

RegisterNUICallback('getJobs', function(_, cb)
  ESX.TriggerServerCallback('fearx-multijob:getJobs', function(jobs, current)
    cb({ jobs = jobs or {}, current = current })
  end)
end)

RegisterNUICallback('selectJob', function(data, cb)
  local job = data and data.job
  local grade = tonumber(data and data.grade) or 0
  if not job then cb({ ok = false }); return end
  TriggerServerEvent('fearx-multijob:setJob', job, grade)
  cb({ ok = true })
end)

RegisterNUICallback('removeJob', function(data, cb)
  local job = data and data.job
  if not job then cb({ ok = false }); return end
  TriggerServerEvent('fearx-multijob:removeJob', job)
  cb({ ok = true })
end)

RegisterNetEvent('esx:setJob', function(job)
  if job and job.name then
    TriggerServerEvent('fearx-multijob:addJob', job.name, tonumber(job.grade or 0) or 0, job.label, (job.grade_label or job.gradeLabel))
  end
end)
