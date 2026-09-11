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

export function App() {
  return <BrowserRouter><AuthProvider><Routes><Route element={<AppShell />}><Route index element={<HomePage />} /><Route path="programs" element={<ProgramsPage />} /><Route path="programs/:programId" element={<ProgramDetailPage />} /><Route path="register" element={<RegisterPage />} /><Route path="login" element={<LoginPage />} /><Route element={<ApplicantRoute/>}><Route path="applications" element={<ApplicationsPage/>}/><Route path="applications/new" element={<ApplicationForm/>}/><Route path="applications/:applicationId" element={<ApplicationDetailPage/>}/><Route path="applications/:applicationId/edit" element={<ApplicationForm edit/>}/></Route><Route path="*" element={<NotFoundPage />} /></Route></Routes></AuthProvider></BrowserRouter>
}
