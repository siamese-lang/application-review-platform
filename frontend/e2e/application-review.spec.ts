import { expect, test, type Page } from '@playwright/test'

const applicant = {
  username: `e2e-applicant-${Date.now()}`,
  password: 'synthetic-applicant-pass-123',
  displayName: 'E2E Applicant',
  organization: 'E2E Synthetic Organization',
  projectTitle: `E2E Review Project ${Date.now()}`,
  shortSummary: 'Initial browser E2E summary.',
  detailedPlan: 'Initial browser E2E detailed plan.',
  revisedPlan: 'Revised browser E2E detailed plan with the requested implementation schedule clarified.',
  amount: '1250000',
}

const reviewer = {
  username: 'e2e-reviewer',
  password: 'synthetic-reviewer-pass-123',
}

async function login(page: Page, username: string, password: string) {
  await page.goto('/login')
  await page.getByLabel('아이디').fill(username)
  await page.getByLabel('비밀번호').fill(password)
  await page.getByRole('button', { name: '로그인' }).click()
}

async function logout(page: Page) {
  await page.getByRole('button', { name: '로그아웃' }).click()
  await expect(page.getByRole('link', { name: '로그인' })).toBeVisible()
}

async function openApplicantApplication(page: Page) {
  await page.getByRole('link', { name: '내 신청' }).click()
  const row = page.getByRole('row').filter({ hasText: applicant.projectTitle })
  await expect(row).toBeVisible()
  await row.getByRole('link', { name: '상세 보기' }).click()
}

async function openReviewerApplication(page: Page) {
  await page.getByRole('link', { name: '심사 업무' }).click()
  const row = page.getByRole('row').filter({ hasText: applicant.projectTitle })
  await expect(row).toBeVisible()
  await row.getByRole('link', { name: '심사하기' }).click()
}

test('public applicant flow and reviewer workflow run against the real stack', async ({ page }) => {
  await page.goto('/programs')
  await expect(page.getByRole('heading', { name: '지원사업' })).toBeVisible()
  await expect(page.getByRole('link', { name: 'Small Business Digital Adoption' })).toBeVisible()

  await page.getByRole('link', { name: 'Small Business Digital Adoption' }).click()
  await expect(page).toHaveURL(/\/programs\/\d+$/)
  await expect(page.getByRole('heading', { name: 'Small Business Digital Adoption', exact: true })).toBeVisible()
  await expect(page.getByText('접수 중', { exact: true })).toBeVisible()
  await expect(page.getByText(/로그인.*회원가입.*신청서/)).toBeVisible()
  await page.getByRole('complementary').getByRole('link', { name: '회원가입', exact: true }).click()

  await page.getByLabel('아이디').fill(applicant.username)
  await page.getByLabel('이름').fill(applicant.displayName)
  await page.getByLabel('이메일 주소').fill(`${applicant.username}@example.test`)
  await page.getByLabel('비밀번호').fill(applicant.password)
  await page.getByRole('button', { name: '신청자 계정 만들기' }).click()
  await expect(page.getByRole('heading', { name: '회원가입 완료' })).toBeVisible()
  await expect(page.getByText(/신청자 계정이 만들어졌습니다/)).toBeVisible()

  await page.getByRole('link', { name: '로그인하기' }).click()
  await page.getByLabel('아이디').fill(applicant.username)
  await page.getByLabel('비밀번호').fill(applicant.password)
  await page.getByRole('button', { name: '로그인' }).click()
  await expect(page.getByRole('link', { name: '내 신청' })).toBeVisible()
  await expect(page.getByRole('link', { name: '심사 업무' })).toHaveCount(0)
  await expect(page.getByRole('link', { name: '관리자' })).toHaveCount(0)

  await page.getByRole('link', { name: 'Small Business Digital Adoption' }).click()
  await page.getByRole('link', { name: '신청서 작성' }).click()
  await expect(page.getByRole('heading', { name: '새 신청서 작성' })).toBeVisible()
  await page.getByLabel('신청 기관명').fill(applicant.organization)
  await page.getByLabel('과제명').fill(applicant.projectTitle)
  await page.getByLabel('요약').fill(applicant.shortSummary)
  await page.getByLabel('신청 금액(원)').fill(applicant.amount)
  await page.getByLabel('세부 계획').fill(applicant.detailedPlan)
  await page.getByRole('button', { name: '임시 저장' }).click()

  await expect(page.getByRole('heading', { name: applicant.projectTitle })).toBeVisible()
  await expect(page.getByText('작성 중', { exact: true })).toBeVisible()

  const evidence = Buffer.from('synthetic browser e2e attachment\n', 'utf8')
  await page.getByLabel('증빙 파일').setInputFiles({
    name: 'e2e-evidence.txt',
    mimeType: 'text/plain',
    buffer: evidence,
  })
  await page.getByRole('button', { name: '파일 올리기' }).click()
  await expect(page.getByText('e2e-evidence.txt')).toBeVisible()
  await expect(page.getByText('업로드 완료', { exact: true })).toBeVisible()

  const downloadPromise = page.waitForEvent('download')
  await page.getByRole('button', { name: '다운로드' }).click()
  const download = await downloadPromise
  expect(download.suggestedFilename()).toBe('e2e-evidence.txt')
  const stream = await download.createReadStream()
  const chunks: Buffer[] = []
  for await (const chunk of stream) chunks.push(Buffer.from(chunk))
  expect(Buffer.concat(chunks).equals(evidence)).toBeTruthy()

  await page.getByRole('link', { name: '수정' }).click()
  await page.getByLabel('요약').fill('Edited browser E2E summary.')
  const draftUpdate = page.waitForResponse((response) =>
    response.request().method() === 'PUT' && /\/api\/v1\/applications\/\d+$/.test(new URL(response.url()).pathname))
  await page.getByRole('button', { name: '변경 내용 저장' }).click()
  expect((await draftUpdate).status()).toBe(200)
  await expect(page).toHaveURL(/\/applications\/\d+$/)
  await expect(page.getByText('Edited browser E2E summary.')).toBeVisible({ timeout: 10_000 })
  await expect(page.getByText('작성 중', { exact: true })).toBeVisible()

  await page.getByRole('button', { name: '최종 제출' }).click()
  await expect(page.getByText('제출 완료', { exact: true })).toBeVisible()
  await expect(page.getByRole('link', { name: '수정' })).toHaveCount(0)
  await expect(page.getByLabel('증빙 파일')).toHaveCount(0)
  await logout(page)

  await login(page, reviewer.username, reviewer.password)
  await expect(page.getByRole('link', { name: '심사 업무' })).toBeVisible()
  await expect(page.getByRole('link', { name: '내 신청' })).toHaveCount(0)
  await expect(page.getByRole('link', { name: '관리자' })).toHaveCount(0)

  await openReviewerApplication(page)
  await expect(page.getByText('e2e-evidence.txt')).toBeVisible()
  await expect(page.getByRole('button', { name: '파일 올리기' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: '삭제' })).toHaveCount(0)
  await page.getByRole('button', { name: '심사 시작' }).click()
  await expect(page.getByText('심사 중', { exact: true })).toBeVisible()
  await expect(page.getByText(/E2E Reviewer \(e2e-reviewer\)/)).toBeVisible()

  await page.getByRole('button', { name: '보완 요청' }).click()
  const revisionReason = 'Please clarify the implementation schedule.'
  await page.getByLabel('처리 사유').fill(revisionReason)
  await page.getByRole('button', { name: '보완 요청 보내기' }).click()
  await expect(page.getByRole('heading', { name: '심사 업무' })).toBeVisible()
  await expect(page.getByText('보완을 요청했습니다.')).toBeVisible()
  await logout(page)

  await login(page, applicant.username, applicant.password)
  await openApplicantApplication(page)
  await expect(page.getByText('보완 요청', { exact: true })).toBeVisible()
  await expect(page.getByText(revisionReason)).toBeVisible()
  await page.getByRole('link', { name: '수정' }).click()
  await page.getByLabel('세부 계획').fill(applicant.revisedPlan)
  const revisionUpdate = page.waitForResponse((response) =>
    response.request().method() === 'PUT' && /\/api\/v1\/applications\/\d+$/.test(new URL(response.url()).pathname))
  await page.getByRole('button', { name: '변경 내용 저장' }).click()
  expect((await revisionUpdate).status()).toBe(200)
  await expect(page).toHaveURL(/\/applications\/\d+$/)
  await expect(page.getByText(applicant.revisedPlan)).toBeVisible({ timeout: 10_000 })
  await page.getByRole('button', { name: '다시 제출' }).click()
  await expect(page.getByText('제출 완료', { exact: true })).toBeVisible()
  await logout(page)

  await login(page, reviewer.username, reviewer.password)
  await openReviewerApplication(page)
  await page.getByRole('button', { name: '심사 시작' }).click()
  await expect(page.getByText('심사 중', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: '승인' }).click()
  await expect(page.getByRole('heading', { name: '심사 업무' })).toBeVisible()
  await expect(page.getByText('신청을 승인했습니다.')).toBeVisible()
  await logout(page)

  await login(page, applicant.username, applicant.password)
  await openApplicantApplication(page)
  await expect(page.getByText('승인', { exact: true }).first()).toBeVisible()
  await expect(page.getByText(/심사 중 → 승인/)).toBeVisible()
  await expect(page.getByRole('link', { name: '수정' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: /최종 제출|다시 제출/ })).toHaveCount(0)
})
