import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './auth/AuthContext'
import { AppShell } from './components/AppShell'
import { HomePage } from './pages/HomePage'
import { LoginPage } from './pages/LoginPage'
import { NotFoundPage } from './pages/NotFoundPage'
import { ProgramDetailPage } from './pages/ProgramDetailPage'
import { ProgramsPage } from './pages/ProgramsPage'
import { RegisterPage } from './pages/RegisterPage'
import { ApplicantRoute } from './components/ApplicantRoute'
import { ApplicationsPage } from './pages/ApplicationsPage'
import { ApplicationForm } from './pages/ApplicationForm'
import { ApplicationDetailPage } from './pages/ApplicationDetailPage'
import { ReviewerRoute } from './components/ReviewerRoute'
import { ReviewQueuePage } from './pages/ReviewQueuePage'
import { ReviewerApplicationPage } from './pages/ReviewerApplicationPage'
import { AdminRoute } from './components/AdminRoute'
import { AdminApplicationDetailPage, AdminApplicationsPage, AdminAuditsPage, AdminDashboardPage, AdminProgramDetailPage, AdminProgramFormPage, AdminProgramsPage, AdminUsersPage } from './pages/AdminPages'

export function App() {
  return <BrowserRouter><AuthProvider><Routes><Route element={<AppShell />}><Route index element={<HomePage />} /><Route path="programs" element={<ProgramsPage />} /><Route path="programs/:programId" element={<ProgramDetailPage />} /><Route path="register" element={<RegisterPage />} /><Route path="login" element={<LoginPage />} /><Route element={<ApplicantRoute/>}><Route path="applications" element={<ApplicationsPage/>}/><Route path="applications/new" element={<ApplicationForm/>}/><Route path="applications/:applicationId" element={<ApplicationDetailPage/>}/><Route path="applications/:applicationId/edit" element={<ApplicationForm edit/>}/></Route><Route element={<ReviewerRoute/>}><Route path="review" element={<ReviewQueuePage/>}/><Route path="review/applications/:applicationId" element={<ReviewerApplicationPage/>}/></Route><Route element={<AdminRoute/>}><Route path="admin" element={<AdminDashboardPage/>}/><Route path="admin/programs" element={<AdminProgramsPage/>}/><Route path="admin/programs/new" element={<AdminProgramFormPage/>}/><Route path="admin/programs/:programId" element={<AdminProgramDetailPage/>}/><Route path="admin/programs/:programId/edit" element={<AdminProgramFormPage edit/>}/><Route path="admin/applications" element={<AdminApplicationsPage/>}/><Route path="admin/applications/:applicationId" element={<AdminApplicationDetailPage/>}/><Route path="admin/users" element={<AdminUsersPage/>}/><Route path="admin/audits" element={<AdminAuditsPage/>}/></Route><Route path="*" element={<NotFoundPage />} /></Route></Routes></AuthProvider></BrowserRouter>
}
