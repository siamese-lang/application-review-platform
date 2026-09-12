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
  await page.getByLabel('Username').fill(username)
  await page.getByLabel('Password').fill(password)
  await page.getByRole('button', { name: 'Log in' }).click()
}

async function logout(page: Page) {
  await page.getByRole('button', { name: 'Log out' }).click()
  await expect(page.getByRole('link', { name: 'Login' })).toBeVisible()
}

async function openApplicantApplication(page: Page) {
  await page.getByRole('link', { name: 'My applications' }).click()
  const row = page.getByRole('row').filter({ hasText: applicant.projectTitle })
  await expect(row).toBeVisible()
  await row.getByRole('link', { name: 'View' }).click()
}

async function openReviewerApplication(page: Page) {
  await page.getByRole('link', { name: 'Review queue' }).click()
  const row = page.getByRole('row').filter({ hasText: applicant.projectTitle })
  await expect(row).toBeVisible()
  await row.getByRole('link', { name: 'Review' }).click()
}

test('public applicant flow and reviewer workflow run against the real stack', async ({ page }) => {
  await page.goto('/programs')
  await expect(page.getByRole('heading', { name: 'Programs' })).toBeVisible()
  await expect(page.getByRole('link', { name: 'Small Business Digital Adoption' })).toBeVisible()

  await page.getByRole('link', { name: 'Small Business Digital Adoption' }).click()
  await expect(page).toHaveURL(/\/programs\/\d+$/)
  await expect(page.getByRole('heading', { name: 'Small Business Digital Adoption', exact: true })).toBeVisible()
  await expect(page.getByText('Open for applications', { exact: true })).toBeVisible()
  await expect(page.getByText(/Log in.*register.*start an application/i)).toBeVisible()
  await page.getByRole('link', { name: 'register', exact: true }).click()

  await page.getByLabel('Username').fill(applicant.username)
  await page.getByLabel('Display name').fill(applicant.displayName)
  await page.getByLabel('Email address').fill(`${applicant.username}@example.test`)
  await page.getByLabel('Password').fill(applicant.password)
  await page.getByRole('button', { name: 'Create applicant account' }).click()
  await expect(page.getByRole('heading', { name: 'Registration complete' })).toBeVisible()
  await expect(page.getByText(/Sign in separately/i)).toBeVisible()

  await page.getByRole('link', { name: 'Continue to login' }).click()
  await page.getByLabel('Username').fill(applicant.username)
  await page.getByLabel('Password').fill(applicant.password)
  await page.getByRole('button', { name: 'Log in' }).click()
  await expect(page.getByRole('link', { name: 'My applications' })).toBeVisible()
  await expect(page.getByRole('link', { name: 'Review queue' })).toHaveCount(0)
  await expect(page.getByRole('link', { name: 'Admin' })).toHaveCount(0)

  await page.getByRole('link', { name: 'Small Business Digital Adoption' }).click()
  await page.getByRole('link', { name: 'Start application' }).click()
  await expect(page.getByRole('heading', { name: 'New application' })).toBeVisible()
  await page.getByLabel('Applicant organization name').fill(applicant.organization)
  await page.getByLabel('Project title').fill(applicant.projectTitle)
  await page.getByLabel('Short summary').fill(applicant.shortSummary)
  await page.getByLabel('Requested amount').fill(applicant.amount)
  await page.getByLabel('Detailed plan').fill(applicant.detailedPlan)
  await page.getByRole('button', { name: 'Save draft' }).click()

  await expect(page.getByRole('heading', { name: applicant.projectTitle })).toBeVisible()
  await expect(page.getByText('Draft', { exact: true })).toBeVisible()

  const evidence = Buffer.from('synthetic browser e2e attachment\n', 'utf8')
  await page.getByLabel('Supporting file').setInputFiles({
    name: 'e2e-evidence.txt',
    mimeType: 'text/plain',
    buffer: evidence,
  })
  await page.getByRole('button', { name: 'Upload' }).click()
  await expect(page.getByText('e2e-evidence.txt')).toBeVisible()
  await expect(page.getByText(/AVAILABLE/)).toBeVisible()

  const downloadPromise = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Download' }).click()
  const download = await downloadPromise
  expect(download.suggestedFilename()).toBe('e2e-evidence.txt')
  const stream = await download.createReadStream()
  const chunks: Buffer[] = []
  for await (const chunk of stream) chunks.push(Buffer.from(chunk))
  expect(Buffer.concat(chunks).equals(evidence)).toBeTruthy()

  await page.getByRole('link', { name: 'Edit' }).click()
  await page.getByLabel('Short summary').fill('Edited browser E2E summary.')
  const draftUpdate = page.waitForResponse((response) =>
    response.request().method() === 'PUT' && /\/api\/v1\/applications\/\d+$/.test(new URL(response.url()).pathname))
  await page.getByRole('button', { name: 'Save changes' }).click()
  expect((await draftUpdate).status()).toBe(200)
  await expect(page).toHaveURL(/\/applications\/\d+$/)
  await expect(page.getByText('Edited browser E2E summary.')).toBeVisible({ timeout: 10_000 })
  await expect(page.getByText('Draft', { exact: true })).toBeVisible()

  await page.getByRole('button', { name: 'Submit' }).click()
  await expect(page.getByText('Submitted', { exact: true })).toBeVisible()
  await expect(page.getByRole('link', { name: 'Edit' })).toHaveCount(0)
  await expect(page.getByLabel('Supporting file')).toHaveCount(0)
  await logout(page)

  await login(page, reviewer.username, reviewer.password)
  await expect(page.getByRole('link', { name: 'Review queue' })).toBeVisible()
  await expect(page.getByRole('link', { name: 'My applications' })).toHaveCount(0)
  await expect(page.getByRole('link', { name: 'Admin' })).toHaveCount(0)

  await openReviewerApplication(page)
  await expect(page.getByText('e2e-evidence.txt')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Upload' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Delete' })).toHaveCount(0)
  await page.getByRole('button', { name: 'Start review' }).click()
  await expect(page.getByText('In review', { exact: true })).toBeVisible()
  await expect(page.getByText(/E2E Reviewer \(e2e-reviewer\)/)).toBeVisible()

  await page.getByRole('button', { name: 'Request revision' }).click()
  const revisionReason = 'Please clarify the implementation schedule.'
  await page.getByLabel('Reason').fill(revisionReason)
  await page.getByRole('button', { name: 'Send revision request' }).click()
  await expect(page.getByRole('heading', { name: 'Review queue' })).toBeVisible()
  await expect(page.getByText('Revision requested.')).toBeVisible()
  await logout(page)

  await login(page, applicant.username, applicant.password)
  await openApplicantApplication(page)
  await expect(page.getByText('Needs revision', { exact: true })).toBeVisible()
  await expect(page.getByText(revisionReason)).toBeVisible()
  await page.getByRole('link', { name: 'Edit' }).click()
  await page.getByLabel('Detailed plan').fill(applicant.revisedPlan)
  const revisionUpdate = page.waitForResponse((response) =>
    response.request().method() === 'PUT' && /\/api\/v1\/applications\/\d+$/.test(new URL(response.url()).pathname))
  await page.getByRole('button', { name: 'Save changes' }).click()
  expect((await revisionUpdate).status()).toBe(200)
  await expect(page).toHaveURL(/\/applications\/\d+$/)
  await expect(page.getByText(applicant.revisedPlan)).toBeVisible({ timeout: 10_000 })
  await page.getByRole('button', { name: 'Resubmit' }).click()
  await expect(page.getByText('Submitted', { exact: true })).toBeVisible()
  await logout(page)

  await login(page, reviewer.username, reviewer.password)
  await openReviewerApplication(page)
  await page.getByRole('button', { name: 'Start review' }).click()
  await expect(page.getByText('In review', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Approve' }).click()
  await expect(page.getByRole('heading', { name: 'Review queue' })).toBeVisible()
  await expect(page.getByText('Application approved.')).toBeVisible()
  await logout(page)

  await login(page, applicant.username, applicant.password)
  await openApplicantApplication(page)
  await expect(page.getByText('Approved', { exact: true }).first()).toBeVisible()
  await expect(page.getByText(/IN_REVIEW → APPROVED/)).toBeVisible()
  await expect(page.getByRole('link', { name: 'Edit' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: /Submit|Resubmit/ })).toHaveCount(0)
})
