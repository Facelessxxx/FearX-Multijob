document.addEventListener('DOMContentLoaded', () => {
  const jobMenuContainer = document.getElementById('job-menu-container')
  const jobList = document.getElementById('job-list')
  const menuPanel = document.getElementById('menu-panel')
  const themeSwitcher = document.getElementById('theme-switcher')
  const headerTitle = document.getElementById('header-title')
  let closeTimer = null
  let jobs = []
  let current = null

  function res() { return `https://${GetParentResourceName()}` }

  function render() {
    jobList.innerHTML = ''
    jobs.forEach((j, index) => {
      const id = j.job || j.id || ''
      const label = j.label || id
      const grade = typeof j.grade === 'number' ? j.grade : parseInt(j.grade || 0, 10) || 0
      const gradeLabel = j.grade_label || j.gradeLabel || ''
      const item = document.createElement('div')
      item.className = 'job-item-wrapper flex items-center justify-between space-x-2'
      item.innerHTML = `
        <div class="job-item p-3 rounded-lg cursor-pointer flex-grow text-center ${current && id === current ? 'active' : ''}" data-job-id="${id}" data-grade="${grade}">
          <span class="font-semibold text-base">${label}${gradeLabel ? ' - ' + gradeLabel : ''}${!gradeLabel && grade ? ' - ' + grade : ''}</span>
        </div>
        <button class="quit-btn p-3 rounded-lg" data-job-id="${id}">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
        </button>`
      jobList.appendChild(item)
      setTimeout(() => { item.style.opacity = '1'; item.style.transform = 'translateX(0)' }, index * 50)
    })
  }

  function loadJobs() {
    fetch(`${res()}/getJobs`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}' })
      .then(r => r.json())
      .then(data => { jobs = Array.isArray(data.jobs) ? data.jobs : []; current = data.current || null; render() })
      .catch(() => {})
  }

  jobList.addEventListener('click', (e) => {
    const jobItem = e.target.closest('.job-item')
    const quitBtn = e.target.closest('.quit-btn')
    if (quitBtn) {
      const jobIdToQuit = quitBtn.dataset.jobId
      fetch(`${res()}/removeJob`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify({ job: jobIdToQuit }) })
        .then(() => loadJobs())
        .catch(() => {})
      return
    }
    if (jobItem) {
      const job = jobItem.dataset.jobId
      const grade = parseInt(jobItem.dataset.grade || '0', 10) || 0
      fetch(`${res()}/selectJob`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify({ job, grade }) })
        .then(() => closeMenu())
        .catch(() => closeMenu())
    }
  })

  function startCloseTimer() { clearTimeout(closeTimer); closeTimer = setTimeout(() => closeMenu(), 5000) }
  jobMenuContainer.addEventListener('mouseenter', () => clearTimeout(closeTimer))
  jobMenuContainer.addEventListener('mouseleave', () => startCloseTimer())

  function openMenu() { loadJobs(); jobMenuContainer.classList.add('open'); startCloseTimer() }
  function closeMenu() { jobMenuContainer.classList.remove('open'); clearTimeout(closeTimer); fetch(`${res()}/close`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}' }) }

  function applyTheme(theme) { menuPanel.classList.remove('theme-light','theme-dark','theme-blue'); if (theme) menuPanel.classList.add(`theme-${theme}`); if (theme) localStorage.setItem('multijobTheme', theme) }
  if (themeSwitcher) { themeSwitcher.addEventListener('click', (e) => { const t = e.target.closest('.theme-btn'); if (t) applyTheme(t.dataset.theme) }) }
  applyTheme(localStorage.getItem('multijobTheme') || 'dark')

  window.addEventListener('message', (event) => { const data = event.data; if (!data) return; if (data.title && headerTitle) headerTitle.textContent = data.title; if (data.action === 'open') openMenu(); else if (data.action === 'close') closeMenu() })
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeMenu() })
})