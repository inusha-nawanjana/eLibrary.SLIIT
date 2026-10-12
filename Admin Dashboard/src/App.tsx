import { useCallback, useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { backendConfigured, supabase } from './backend';

type Page = 'dashboard' | 'pending' | 'addBooks' | 'profile';
type Kind = 'book' | 'learning' | 'discussion';
type ReservationFilter = 'all' | 'pending' | 'active' | 'rejected' | 'completed';
type Reservation = {
  id: string;
  kind: Kind;
  status: string;
  full_name: string;
  phone: string;
  member_ids: string[];
  id_paths: string[];
  starts_at: string | null;
  ends_at: string | null;
  due_date: string | null;
  admin_note: string | null;
  created_at: string;
  book_id: string | null;
  room_id: string | null;
  books: { title: string; author: string } | null;
  rooms: { kind: Kind; number: number; capacity: number } | null;
};
type Room = { id: string; kind: 'learning' | 'discussion'; number: number; capacity: number; enabled: boolean };
type Book = { id: string; title: string; copies: number; ebook_path: string | null };
type Profile = { id: string; campus_id: string; full_name: string; phone: string; role: string; avatar_path: string | null };
type RequestCard = { id: string; k: Kind; title: string; person: string; status: string; capacity?: string; time?: string; when?: string };
type Dialog = { title: string; text: string; button: string; extra?: string; kind?: 'error' | 'success' };

const categories = ['Computer Science', 'Management', 'Law', 'Cookery', 'Data Science', 'Engineering'];
const tabs: [Kind, string][] = [['book', 'Books'], ['learning', 'Learning Space'], ['discussion', 'Discussion Space']];
const statusTabs: [ReservationFilter, string][] = [['all', 'All'], ['pending', 'Pending'], ['active', 'Active'], ['rejected', 'Rejected'], ['completed', 'Complete']];
const allowedRoles = ['admin', 'librarian', 'library_staff'];

function Icon({ name }: { name: string }) {
  const base = { viewBox: '0 0 24 24', width: 24, height: 24, fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, 'aria-hidden': true as const };
  if (name === 'Dashboard') return <svg {...base}><path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z" fill="currentColor" stroke="none"/></svg>;
  if (name === 'Pending') return <svg {...base}><rect x="4" y="4" width="16" height="17" rx="2" fill="currentColor" stroke="none"/><path d="M9 3v4M15 3v4M8 11h8" stroke="#112850"/></svg>;
  if (name === 'Add Books') return <svg {...base}><path d="M4 5a2 2 0 0 1 2-2h14v17H6a2 2 0 0 0-2 2z" fill="currentColor" stroke="none"/><path d="M4 5v17M8 7h8M8 10h8" stroke="#112850"/></svg>;
  if (name === 'Profile') return <svg {...base}><circle cx="12" cy="12" r="8" fill="currentColor" stroke="none"/></svg>;
  const d = name === 'note' ? 'M4 5.5A1.5 1.5 0 0 1 5.5 4h13A1.5 1.5 0 0 1 20 5.5v10a1.5 1.5 0 0 1-1.5 1.5H9l-5 4z' : 'M5 12h14m-6-6 6 6-6 6';
  return <svg {...base}><path d={d}/></svg>;
}

function errorText(error: unknown) {
  if (error && typeof error === 'object' && 'message' in error) return String(error.message);
  return String(error);
}

function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [authError, setAuthError] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [signingIn, setSigningIn] = useState(false);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [avatarUrl, setAvatarUrl] = useState('');
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [rooms, setRooms] = useState<Room[]>([]);
  const [books, setBooks] = useState<Book[]>([]);
  const [page, setPage] = useState<Page>('dashboard');
  const [kind, setKind] = useState<Kind>('book');
  const [reservationFilter, setReservationFilter] = useState<ReservationFilter>('all');
  const [form, setForm] = useState<'physical' | 'ebook' | 'note' | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [ebookFile, setEbookFile] = useState<File | null>(null);
  const [notePhotos, setNotePhotos] = useState<File[]>([]);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [dialog, setDialog] = useState<Dialog | null>(null);
  const [active, setActive] = useState<{ r: RequestCard; a: 'approve' | 'reject' } | null>(null);
  const [reason, setReason] = useState('There is an inconsistency in your information; therefore, we are rejecting this request.');
  const [decisionNote, setDecisionNote] = useState('');

  useEffect(() => {
    if (!supabase) { setAuthReady(true); setLoading(false); return; }
    let alive = true;
    supabase.auth.getSession().then(({ data, error }) => {
      if (!alive) return;
      if (error) setAuthError(error.message);
      setSession(data.session);
      setAuthReady(true);
    }).catch(error => { if (alive) { setAuthError(errorText(error)); setAuthReady(true); } });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, next) => setSession(next));
    return () => { alive = false; listener.subscription.unsubscribe(); };
  }, []);

  const refresh = useCallback(async () => {
    if (!supabase || !session) return;
    setLoading(true);
    setLoadError('');
    try {
      const [profileResult, reservationResult, roomResult, bookResult] = await Promise.all([
        supabase.from('profiles').select('id,campus_id,full_name,phone,role,avatar_path').eq('id', session.user.id).single(),
        supabase.from('reservations').select('*,books(title,author),rooms(kind,number,capacity)').order('created_at', { ascending: false }),
        supabase.from('rooms').select('id,kind,number,capacity,enabled').order('kind').order('number'),
        supabase.from('books').select('id,title,copies,ebook_path'),
      ]);
      if (profileResult.error) throw profileResult.error;
      if (reservationResult.error) throw reservationResult.error;
      if (roomResult.error) throw roomResult.error;
      if (bookResult.error) throw bookResult.error;
      const staff = profileResult.data as Profile;
      if (!allowedRoles.includes(staff.role)) {
        await supabase.auth.signOut();
        setEmail('');
        setPassword('');
        setAuthError('This account does not have librarian, library staff, or administrator access.');
        setSession(null);
        return;
      }
      setProfile(staff);
      setReservations(reservationResult.data as unknown as Reservation[]);
      setRooms(roomResult.data as Room[]);
      setBooks(bookResult.data as Book[]);
      if (staff.avatar_path) {
        const { data } = await supabase.storage.from('avatars').createSignedUrl(staff.avatar_path, 3600);
        setAvatarUrl(data?.signedUrl ?? '');
      } else setAvatarUrl('');
    } catch (error) {
      setLoadError(errorText(error));
    } finally {
      setLoading(false);
    }
  }, [session]);

  useEffect(() => { if (session) void refresh(); else if (authReady) setLoading(false); }, [session, authReady, refresh]);

  const signIn = async (event: FormEvent) => {
    event.preventDefault();
    if (!supabase) return;
    setSigningIn(true);
    setAuthError('');
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (error) throw error;
      setSession(data.session);
    } catch (error) { setAuthError(errorText(error)); }
    finally { setSigningIn(false); }
  };

  const signOut = async () => {
    if (!supabase) return;
    setBusy(true);
    const { error } = await supabase.auth.signOut();
    setBusy(false);
    if (error) setDialog({ title: 'Could not log out', text: error.message, button: 'Close', kind: 'error' });
    else {
      setEmail('');
      setPassword('');
      setAuthError('');
      setSession(null);
      setProfile(null);
      setReservations([]);
      setRooms([]);
      setBooks([]);
      setPage('dashboard');
    }
  };

  const go = (next: Page) => { setPage(next); setForm(null); setCoverFile(null); setEbookFile(null); };
  const jump = (nextKind: Kind) => { setKind(nextKind); setReservationFilter('pending'); go('pending'); };
  const pending = useMemo(() => reservations.filter(r => r.status === 'pending'), [reservations]);
  const categoryReservations = useMemo(() => reservations.filter(r => r.kind === kind), [reservations, kind]);
  const filteredReservations = useMemo(() => categoryReservations.filter(r => {
    if (reservationFilter === 'all') return true;
    if (reservationFilter === 'active') return ['approved', 'active'].includes(r.status);
    if (reservationFilter === 'completed') return r.status === 'completed';
    return r.status === reservationFilter;
  }), [categoryReservations, reservationFilter]);
  const requestCards = useMemo(() => filteredReservations.map(r => {
    const title = r.kind === 'book'
      ? (r.books?.title ?? 'Book reservation')
      : `${r.kind === 'learning' ? 'Learning' : 'Discussion'} Room ${r.rooms?.number ?? ''}`;
    const when = r.created_at ? new Date(r.created_at).toLocaleString() : '';
    const time = r.starts_at && r.ends_at
      ? `${new Date(r.starts_at).toLocaleString()} – ${new Date(r.ends_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`
      : '';
    return { id: r.id, k: r.kind, title, person: `${r.full_name} (${r.phone})`, status: r.status, capacity: r.rooms ? `${r.rooms.capacity} People` : undefined, time, when } satisfies RequestCard;
  }), [filteredReservations]);

  const availableRooms = (roomKind: 'learning' | 'discussion') => {
    const now = Date.now();
    const enabled = rooms.filter(r => r.enabled && r.kind === roomKind);
    const occupiedIds = new Set(reservations
      .filter(r => r.room_id && ['approved', 'active'].includes(r.status) && r.starts_at && r.ends_at && Date.parse(r.starts_at) <= now && Date.parse(r.ends_at) > now)
      .map(r => r.room_id));
    return `${enabled.filter(r => !occupiedIds.has(r.id)).length}/${enabled.length}`;
  };

  const finishReview = async () => {
    if (!supabase || !active) return;
    setBusy(true);
    try {
      const reservation = reservations.find(item => item.id === active.r.id);
      if (!reservation) throw new Error('Reservation is no longer available. Refresh and try again.');
      const { error } = await supabase.rpc('review_reservation', {
        p_id: reservation.id,
        p_status: active.a === 'approve' ? 'active' : 'rejected',
        p_note: active.a === 'reject' ? reason.trim() : decisionNote.trim(),
      });
      if (error) throw error;
      const title = active.a === 'approve' ? 'Reservation Activated' : 'Request Rejected';
      setActive(null);
      setDecisionNote('');
      await refresh();
      setDialog({ title, text: active.a === 'approve' ? 'The reservation is now active and the requester will be notified.' : 'The rejection note was saved and the requester will be notified.', button: 'Done', extra: active.a === 'reject' ? reason.trim() : (decisionNote.trim() || undefined), kind: 'success' });
    } catch (error) {
      setDialog({ title: 'Unable to update reservation', text: errorText(error), button: 'Close', kind: 'error' });
    } finally { setBusy(false); }
  };

  const submitBook = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!supabase || !form || form === 'note') return;
    const ebook = form === 'ebook';
    const values = new FormData(event.currentTarget);
    const title = String(values.get('title') ?? '').trim();
    const author = String(values.get('author') ?? '').trim();
    const year = Number(values.get('year') ?? 0);
    const category = String(values.get('category') ?? '');
    const shelf = String(values.get('shelf') ?? '').trim();
    const copies = Math.max(1, Number(values.get('copies') ?? 1));
    if (!coverFile) { setDialog({ title: 'Book cover required', text: 'Choose a cover photo before saving this book.', button: 'Close', kind: 'error' }); return; }
    if (ebook && !ebookFile) { setDialog({ title: 'eBook file required', text: 'Choose a PDF file before saving this eBook.', button: 'Close', kind: 'error' }); return; }
    setBusy(true);
    const uploaded: { bucket: string; path: string }[] = [];
    const token = globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    try {
      const coverPath = `catalogue/${token}.${coverFile.type === 'image/png' ? 'png' : coverFile.type === 'image/webp' ? 'webp' : 'jpg'}`;
      const coverUpload = await supabase.storage.from('book-covers').upload(coverPath, coverFile, { contentType: coverFile.type, upsert: false });
      if (coverUpload.error) throw coverUpload.error;
      uploaded.push({ bucket: 'book-covers', path: coverPath });
      let ebookPath: string | null = null;
      if (ebookFile) {
        ebookPath = `catalogue/${token}.pdf`;
        const pdfUpload = await supabase.storage.from('ebooks').upload(ebookPath, ebookFile, { contentType: 'application/pdf', upsert: false });
        if (pdfUpload.error) throw pdfUpload.error;
        uploaded.push({ bucket: 'ebooks', path: ebookPath });
      }
      const { error } = await supabase.from('books').insert({
        title, author, category, published_year: year, copies,
        shelf: ebook ? '' : shelf, cover_path: coverPath, ebook_path: ebookPath,
      });
      if (error) throw error;
      setCoverFile(null); setEbookFile(null); setForm(null);
      await refresh();
      setDialog({ title: ebook ? 'eBook Added Successfully' : 'Book Added Successfully', text: 'The book is now available in the shared eLibrary catalogue.', button: 'Done', kind: 'success' });
    } catch (error) {
      for (const object of uploaded) {
        try { await supabase.storage.from(object.bucket).remove([object.path]); } catch { /* retain original error */ }
      }
      setDialog({ title: 'Could not add book', text: errorText(error), button: 'Close', kind: 'error' });
    } finally { setBusy(false); }
  };

  const submitAnnouncement = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!supabase || !session) return;
    const values = new FormData(event.currentTarget);
    const title = String(values.get('heading') ?? '').trim();
    const body = String(values.get('description') ?? '').trim();
    const invalidPhoto = notePhotos.find(file =>
      !['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 5 * 1024 * 1024,
    );
    if (invalidPhoto) {
      setDialog({ title: 'Invalid announcement photo', text: 'Use JPG, PNG, or WebP photos up to 5 MB each.', button: 'Close', kind: 'error' });
      return;
    }

    setBusy(true);
    const uploaded: string[] = [];
    const token = globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    try {
      for (const [index, file] of notePhotos.entries()) {
        const extension = file.type === 'image/png' ? 'png' : file.type === 'image/webp' ? 'webp' : 'jpg';
        const path = `announcements/${token}-${index}.${extension}`;
        const { error } = await supabase.storage.from('announcement-images').upload(path, file, { contentType: file.type, upsert: false });
        if (error) throw error;
        uploaded.push(path);
      }
      const { error } = await supabase.from('announcements').insert({ title, body, image_paths: uploaded, author_id: session.user.id });
      if (error) throw error;
      setNotePhotos([]);
      setForm(null);
      setDialog({ title: 'Note Published Successfully', text: 'The update is saved and has been sent to users in the Student View notifications.', button: 'Done', kind: 'success' });
    } catch (error) {
      if (uploaded.length) {
        try { await supabase.storage.from('announcement-images').remove(uploaded); } catch { /* Keep the original backend error. */ }
      }
      setDialog({ title: 'Could not publish note', text: errorText(error), button: 'Close', kind: 'error' });
    } finally { setBusy(false); }
  };

  const metric = (label: ReactNode, value: string, tone = 'orange', onClick?: () => void) =>
    <button className="metric" onClick={onClick}><span>{label}</span><b className={tone}>{value}</b></button>;
  const field = (label: string, child: ReactNode) => <label className="field"><span>{label}</span>{child}</label>;
  const upload = (label: string, accept: string, onFile: (file: File | null) => void, selected?: File | null) =>
    <label className="upload"><span>{label}</span><span className="drop">▣<small>{selected?.name ?? 'Drag & drop or Click to upload'}</small><input type="file" accept={accept} onChange={event => onFile(event.currentTarget.files?.[0] ?? null)}/></span></label>;

  if (!backendConfigured) return <main className="auth-screen"><section className="auth-card"><div className="auth-brand">eLibrary<span>.SLIIT</span></div><h1>Backend setup required</h1><p>Configure the Supabase URL and publishable key in the local <code>.env.local</code> file, then restart the dashboard.</p></section></main>;
  if (!authReady || (session && !profile && loading)) return <main className="auth-screen"><section className="auth-card"><div className="spinner"/><p>Connecting to the eLibrary service…</p></section></main>;
  if (!session) return <main className="auth-screen"><form className="auth-card" onSubmit={signIn} autoComplete="off"><div className="auth-brand">eLibrary<span>.SLIIT</span></div><p className="eyebrow">LIBRARY STAFF PORTAL</p><h1>Welcome back</h1><p>Sign in with your SLIIT library staff account.</p>{authError&&<div className="error-banner">{authError}</div>}<label className="auth-field"><span>Email address</span><input type="email" name="admin-login-email" autoComplete="off" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="name@my.sliit.lk"/></label><label className="auth-field"><span>Password</span><input type="password" name="admin-login-password" autoComplete="new-password" required value={password} onChange={e=>setPassword(e.target.value)}/></label><button className="auth-submit" disabled={signingIn}>{signingIn?'Signing in…':'Sign In'}</button></form></main>;

  return <main className="device">
    <div className="content">
      {loadError && <div className="error-banner page-error">{loadError}<button onClick={() => void refresh()}>Try again</button></div>}
      {page==='dashboard'&&<><header className="brand"><b>eLibrary<span>.SLIIT</span></b><small>The Knowledge University</small></header><div className="page-heading"><h1 className="dash-title">Admin Dashboard</h1><button className="refresh-button" onClick={() => void refresh()} disabled={loading}>{loading?'Refreshing…':'↻ Refresh'}</button></div><section className="welcome"><h2>Welcome, {profile?.full_name ?? 'Administrator'}</h2><p>eLibrary.SLIIT Management Portal</p></section><div className="metrics">
        {metric(<>Pending Books<br/>Reservations</>,String(pending.filter(r=>r.kind==='book').length),'orange',()=>jump('book'))}
        {metric(<>Pending Learning Space<br/>Reservations</>,String(pending.filter(r=>r.kind==='learning').length),'orange',()=>jump('learning'))}
        {metric(<>Pending Discussion<br/>Space Reservations</>,String(pending.filter(r=>r.kind==='discussion').length),'orange',()=>jump('discussion'))}
        {metric(<>Available Learning<br/>Spaces</>,availableRooms('learning'),'green')}
        {metric(<>Available Discussion<br/>Spaces</>,availableRooms('discussion'),'green')}
        {metric(<>Books Reserved<br/>or Borrowed Now</>,String(reservations.filter(r=>r.kind==='book'&&['approved','active'].includes(r.status)).length),'navy',()=>jump('book'))}</div></>}
      {page==='pending'&&<><h1 className="title">Reservations</h1><div className="tabs">{tabs.map(([k,t])=><button className={kind===k?'sel':''} key={k} onClick={()=>setKind(k)}>{t}</button>)}</div><div className="status-tabs" role="tablist" aria-label="Filter reservations by status">{statusTabs.map(([status,label])=><button key={status} role="tab" aria-selected={reservationFilter===status} className={reservationFilter===status?'status-sel':''} onClick={()=>setReservationFilter(status)}>{label}<small>{categoryReservations.filter(r=>status==='all'||(status==='active'?['approved','active'].includes(r.status):status==='completed'?r.status==='completed':r.status===status)).length}</small></button>)}</div><section className="requests">{requestCards.map(r=><article className="request" key={r.id}><div className="request-title-row"><h2>{r.title}</h2><span className={'reservation-status status-'+r.status}>{r.status==='completed'?'Complete':r.status==='rejected'?'Rejected':r.status==='approved'?'Approved':r.status==='active'?'Active':r.status==='cancelled'?'Cancelled':'Pending'}</span></div><p>{r.k==='discussion'?'Lecturer:':'Student:'} {r.person}</p>{r.k==='book'?<p>Requested: {r.when}</p>:<><p>Capacity: {r.capacity}</p><p className="time">Reservation: {r.time}</p></>}<p>Reservation ID: <b>#{r.id}</b></p>{r.status==='pending'&&<div className="actions"><button disabled={busy} onClick={()=>setActive({r,a:'approve'})}>Approve</button><button disabled={busy} onClick={()=>setActive({r,a:'reject'})}>Reject</button></div>}</article>)}{!loading&&requestCards.length===0&&<p className="empty">No {reservationFilter==='all'?'':reservationFilter+' '}reservations in this category</p>}</section></>}
      {page==='addBooks'&&!form&&<><h1 className="title add-title">Add Books</h1><button className="note" onClick={()=>setForm('note')}><Icon name="note"/>Click here to post a note.<Icon name="arrow"/></button><section className="type-list"><button className="type-card" onClick={()=>{setForm('physical');setCoverFile(null)}}><img src="/assets/physical-books.jpeg"/><b>Physical Books</b><span>To the Library</span><i>→</i></button><button className="type-card" onClick={()=>{setForm('ebook');setCoverFile(null);setEbookFile(null)}}><img src="/assets/ebooks.jpeg"/><b>E-Books</b><span>To the Library Portal</span><i>→</i></button></section></>}
      {page==='addBooks'&&(form==='physical'||form==='ebook')&&<form className="form" onSubmit={submitBook}><button type="button" className="form-head" onClick={()=>setForm(null)}>← Add New Book</button>{field('Book Name',<input name="title" required placeholder="e.g., Designing Data-Intensive Applications"/>)}{field('Author',<input name="author" required placeholder="e.g., Martin Kleppmann"/>)}{field('Published Year',<input name="year" type="number" min="1" max={new Date().getFullYear()} required placeholder="e.g., 2024"/>)}{field('Category',<select name="category" required defaultValue="Computer Science">{categories.map(item=><option key={item}>{item}</option>)}</select>)}{form==='physical'&&<>{field('Bookshelf Location',<input name="shelf" required placeholder="e.g., CS-04-B"/>)}{field('Number of Copies',<input name="copies" type="number" min="1" defaultValue="1" required/>)}</>}{upload('Upload Book Cover','image/jpeg,image/png,image/webp',setCoverFile,coverFile)}{form==='ebook'&&upload('Upload eBook PDF','application/pdf',setEbookFile,ebookFile)}<button className="submit" disabled={busy}>{busy?'Saving…':'Add Book'}</button></form>}
      {page==='addBooks'&&form==='note'&&<form className="form note-form" onSubmit={submitAnnouncement}><button type="button" className="form-head" onClick={()=>{setForm(null);setNotePhotos([])}}>← Add a Note for Publish</button>{field('Heading',<input name="heading" maxLength={120} required placeholder="e.g., Resource Update: UI/UX Design Trends"/>)}{field('Description',<textarea name="description" maxLength={4000} required placeholder="The latest edition has just been added to the eLibrary."/>) }<label className="upload"><span>Upload Photos</span><span className="drop">▣<small>{notePhotos.length ? `${notePhotos.length} photo${notePhotos.length===1?'':'s'} selected` : 'Drag & drop or Click to upload'}</small><input type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={event=>setNotePhotos(Array.from(event.currentTarget.files ?? []))}/></span></label><button className="submit" disabled={busy}>{busy?'Publishing…':'Send Note'}</button></form>}
      {page==='profile'&&<><h1 className="title">Admin Profile</h1><section className="identity"><img src={avatarUrl||'/assets/admin-profile.jpeg'} onError={event=>{event.currentTarget.src='/assets/admin-profile.jpeg'}}/><h2>{profile?.full_name}</h2><p>{profile?.role==='admin'?'Administrator':profile?.role==='librarian'?'Librarian':'Library Staff'}</p></section><section className="details">{[['Admin ID',profile?.campus_id??''],['Email Address',session.user.email??''],['Phone Number',profile?.phone||'Not provided'],['Role',profile?.role??'']].map(([a,b])=><div key={a}><span>{a}</span><b>{b}</b></div>)}</section><button className="logout" disabled={busy} onClick={()=>setDialog({title:'Log Out Account',text:'Are you sure you want to log out of the admin account?',button:'Log Out'})}>Log Out Account</button></>}
    </div>
    <nav className="nav"><div className="sidebar-brand"><b>eLibrary<span>.SLIIT</span></b><small>ADMINISTRATION</small></div><div className="sidebar-user">{profile?.full_name}<span>{profile?.role?.replace('_',' ')}</span></div>{(['dashboard','pending','addBooks','profile'] as Page[]).map((p,i)=>{const n=['Dashboard','Pending','Add Books','Profile'][i];return <button key={p} className={page===p?'active':''} onClick={()=>go(p)}><Icon name={n}/><span>{n}</span>{p==='pending'&&pending.length>0&&<b className="nav-count">{pending.length}</b>}</button>})}<button className="nav-logout" onClick={()=>setDialog({title:'Log Out Account',text:'Are you sure you want to log out of the admin account?',button:'Log Out'})}>↪ <span>Log Out</span></button></nav>
    {active&&<div className="veil"><section className="dialog"><i className="clock">{active.a==='reject'?'!':'✓'}</i><h2>{active.a==='reject'?'Reason for Rejection':'Approve Reservation?'}</h2>{active.a==='reject'?<textarea className="reason" value={reason} onChange={e=>setReason(e.target.value)}/>:<><p>{active.r.title} · {active.r.person}</p><textarea className="reason" placeholder="Add a note for this approval (optional)" value={decisionNote} onChange={e=>setDecisionNote(e.target.value)}/></>}<p className="rid">Reservation ID<br/><b>#{active.r.id}</b></p><button className="dialog-button" disabled={busy} onClick={()=>void finishReview()}>{busy?'Saving…':active.a==='reject'?'Reject Request':'Approve'}</button><button className="cancel" disabled={busy} onClick={()=>setActive(null)}>Cancel</button></section></div>}
    {dialog&&<div className="veil"><section className="dialog"><i className="clock">{dialog.kind==='error'?'!':'✓'}</i><h2>{dialog.title}</h2><p>{dialog.text}</p>{dialog.extra&&<p className="rid">Note<br/><b>{dialog.extra}</b></p>}<button className="dialog-button" onClick={()=>{const logout=dialog.title==='Log Out Account';setDialog(null);if(logout)void signOut();}}>{dialog.button}</button><button className="cancel" onClick={()=>setDialog(null)}>Cancel</button></section></div>}
  </main>;
}
export default App;
