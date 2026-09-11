import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, expect, it, vi } from 'vitest'
import { AuthProvider } from '../auth/AuthContext'
import { AdminRoute } from './AdminRoute'

afterEach(() => { cleanup(); vi.unstubAllGlobals() })
function view(role: string) { vi.stubGlobal('fetch', vi.fn(() => Promise.resolve(new Response(JSON.stringify({ id: 1, username: 'user', displayName: 'User', email: 'user@example.test', role }), { status: 200, headers: { 'Content-Type': 'application/json' } })))); return render(<MemoryRouter initialEntries={['/admin']}><AuthProvider><Routes><Route element={<AdminRoute/>}><Route path="/admin" element={<h1>Admin content</h1>}/></Route></Routes></AuthProvider></MemoryRouter>) }
it('allows administrators', async () => { view('ADMIN'); expect(await screen.findByRole('heading', { name: 'Admin content' })).toBeInTheDocument() })
it('blocks non-administrators', async () => { view('REVIEWER'); expect(await screen.findByRole('alert')).toHaveTextContent('Administrator access required'); expect(screen.queryByText('Admin content')).not.toBeInTheDocument() })
