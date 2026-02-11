-- School Management System - Normalized PostgreSQL Schema + Seed Data
-- This file is intended for local demo/tests.
-- It is idempotent: re-running should not fail (drops + recreates).
--
-- NOTE: This container's scripts use DB:
--   postgresql://appuser:dbuser123@localhost:5000/myapp

BEGIN;

-- Extensions (safe)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------------
-- Drop in dependency-safe order
-- -------------------------------------------------------------------
DO $$
BEGIN
  -- fact tables / junctions
  IF to_regclass('public.audit_log') IS NOT NULL THEN EXECUTE 'DROP TABLE public.audit_log CASCADE'; END IF;
  IF to_regclass('public.user_sessions') IS NOT NULL THEN EXECUTE 'DROP TABLE public.user_sessions CASCADE'; END IF;

  IF to_regclass('public.notice_audience') IS NOT NULL THEN EXECUTE 'DROP TABLE public.notice_audience CASCADE'; END IF;
  IF to_regclass('public.notices') IS NOT NULL THEN EXECUTE 'DROP TABLE public.notices CASCADE'; END IF;

  IF to_regclass('public.timetable_entries') IS NOT NULL THEN EXECUTE 'DROP TABLE public.timetable_entries CASCADE'; END IF;

  IF to_regclass('public.fee_payments') IS NOT NULL THEN EXECUTE 'DROP TABLE public.fee_payments CASCADE'; END IF;
  IF to_regclass('public.fee_invoices') IS NOT NULL THEN EXECUTE 'DROP TABLE public.fee_invoices CASCADE'; END IF;
  IF to_regclass('public.fee_structures') IS NOT NULL THEN EXECUTE 'DROP TABLE public.fee_structures CASCADE'; END IF;

  IF to_regclass('public.exam_results') IS NOT NULL THEN EXECUTE 'DROP TABLE public.exam_results CASCADE'; END IF;
  IF to_regclass('public.exam_schedule') IS NOT NULL THEN EXECUTE 'DROP TABLE public.exam_schedule CASCADE'; END IF;
  IF to_regclass('public.exams') IS NOT NULL THEN EXECUTE 'DROP TABLE public.exams CASCADE'; END IF;

  IF to_regclass('public.attendance') IS NOT NULL THEN EXECUTE 'DROP TABLE public.attendance CASCADE'; END IF;

  IF to_regclass('public.enrollments') IS NOT NULL THEN EXECUTE 'DROP TABLE public.enrollments CASCADE'; END IF;

  IF to_regclass('public.teacher_subjects') IS NOT NULL THEN EXECUTE 'DROP TABLE public.teacher_subjects CASCADE'; END IF;
  IF to_regclass('public.section_subjects') IS NOT NULL THEN EXECUTE 'DROP TABLE public.section_subjects CASCADE'; END IF;

  IF to_regclass('public.sections') IS NOT NULL THEN EXECUTE 'DROP TABLE public.sections CASCADE'; END IF;
  IF to_regclass('public.classes') IS NOT NULL THEN EXECUTE 'DROP TABLE public.classes CASCADE'; END IF;
  IF to_regclass('public.subjects') IS NOT NULL THEN EXECUTE 'DROP TABLE public.subjects CASCADE'; END IF;

  IF to_regclass('public.teachers') IS NOT NULL THEN EXECUTE 'DROP TABLE public.teachers CASCADE'; END IF;
  IF to_regclass('public.students') IS NOT NULL THEN EXECUTE 'DROP TABLE public.students CASCADE'; END IF;

  -- rbac
  IF to_regclass('public.user_roles') IS NOT NULL THEN EXECUTE 'DROP TABLE public.user_roles CASCADE'; END IF;
  IF to_regclass('public.role_permissions') IS NOT NULL THEN EXECUTE 'DROP TABLE public.role_permissions CASCADE'; END IF;
  IF to_regclass('public.permissions') IS NOT NULL THEN EXECUTE 'DROP TABLE public.permissions CASCADE'; END IF;
  IF to_regclass('public.roles') IS NOT NULL THEN EXECUTE 'DROP TABLE public.roles CASCADE'; END IF;
  IF to_regclass('public.users') IS NOT NULL THEN EXECUTE 'DROP TABLE public.users CASCADE'; END IF;
END $$;

-- -------------------------------------------------------------------
-- Enumerations (use CHECK constraints to keep simple/portable)
-- -------------------------------------------------------------------

-- -------------------------------------------------------------------
-- RBAC / Auth / Users
-- -------------------------------------------------------------------
CREATE TABLE public.users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email            TEXT NOT NULL UNIQUE,
  username         TEXT UNIQUE,
  password_hash    TEXT NOT NULL,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  is_superuser     BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at    TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT users_email_chk CHECK (position('@' in email) > 1)
);

CREATE INDEX idx_users_is_active ON public.users(is_active);

CREATE TABLE public.roles (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL UNIQUE,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.permissions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code         TEXT NOT NULL UNIQUE,   -- e.g. "students.read"
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.user_roles (
  user_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role_id   UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id)
);

CREATE INDEX idx_user_roles_role_id ON public.user_roles(role_id);

CREATE TABLE public.role_permissions (
  role_id       UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);

CREATE INDEX idx_role_permissions_permission_id ON public.role_permissions(permission_id);

-- Optional: sessions for auditability / demo
CREATE TABLE public.user_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ,
  ip_address    INET,
  user_agent    TEXT
);
CREATE INDEX idx_user_sessions_user_id_created_at ON public.user_sessions(user_id, created_at DESC);

-- -------------------------------------------------------------------
-- Core entities: Students / Teachers
-- -------------------------------------------------------------------
CREATE TABLE public.students (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID UNIQUE REFERENCES public.users(id) ON DELETE SET NULL,
  admission_no    TEXT NOT NULL UNIQUE,
  first_name      TEXT NOT NULL,
  last_name       TEXT NOT NULL,
  dob             DATE,
  gender          TEXT,
  phone           TEXT,
  address         TEXT,
  guardian_name   TEXT,
  guardian_phone  TEXT,
  status          TEXT NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT students_status_chk CHECK (status IN ('active','inactive','graduated','transferred'))
);

CREATE INDEX idx_students_name ON public.students(last_name, first_name);
CREATE INDEX idx_students_status ON public.students(status);

CREATE TABLE public.teachers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID UNIQUE REFERENCES public.users(id) ON DELETE SET NULL,
  employee_no     TEXT NOT NULL UNIQUE,
  first_name      TEXT NOT NULL,
  last_name       TEXT NOT NULL,
  email           TEXT,
  phone           TEXT,
  hire_date       DATE,
  status          TEXT NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT teachers_status_chk CHECK (status IN ('active','inactive','terminated'))
);

CREATE INDEX idx_teachers_name ON public.teachers(last_name, first_name);

-- -------------------------------------------------------------------
-- Academics: Classes / Sections / Subjects
-- -------------------------------------------------------------------
CREATE TABLE public.classes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL UNIQUE, -- e.g. "Grade 1"
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.sections (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id           UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  name              TEXT NOT NULL, -- e.g. "A", "B"
  class_teacher_id  UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
  room              TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (class_id, name)
);

CREATE INDEX idx_sections_class_id ON public.sections(class_id);
CREATE INDEX idx_sections_class_teacher_id ON public.sections(class_teacher_id);

CREATE TABLE public.subjects (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT NOT NULL UNIQUE,   -- e.g. "MATH"
  name        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_subjects_name ON public.subjects(name);

-- Subjects offered in a section
CREATE TABLE public.section_subjects (
  section_id  UUID NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
  subject_id  UUID NOT NULL REFERENCES public.subjects(id) ON DELETE RESTRICT,
  PRIMARY KEY (section_id, subject_id)
);

CREATE INDEX idx_section_subjects_subject_id ON public.section_subjects(subject_id);

-- Teachers assigned to subjects (optionally per section)
CREATE TABLE public.teacher_subjects (
  teacher_id  UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  subject_id  UUID NOT NULL REFERENCES public.subjects(id) ON DELETE RESTRICT,
  section_id  UUID REFERENCES public.sections(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (teacher_id, subject_id, section_id)
);

CREATE INDEX idx_teacher_subjects_subject_id ON public.teacher_subjects(subject_id);
CREATE INDEX idx_teacher_subjects_section_id ON public.teacher_subjects(section_id);

-- -------------------------------------------------------------------
-- Enrollment: Student <-> Section per Academic Year
-- -------------------------------------------------------------------
CREATE TABLE public.enrollments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  section_id    UUID NOT NULL REFERENCES public.sections(id) ON DELETE RESTRICT,
  academic_year TEXT NOT NULL, -- e.g. "2025-2026"
  roll_no       INT,
  start_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date      DATE,
  status        TEXT NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT enrollments_status_chk CHECK (status IN ('active','inactive','completed','withdrawn')),
  CONSTRAINT enrollments_dates_chk CHECK (end_date IS NULL OR end_date >= start_date),
  UNIQUE (student_id, academic_year),
  UNIQUE (section_id, academic_year, roll_no)
);

CREATE INDEX idx_enrollments_section_year ON public.enrollments(section_id, academic_year);
CREATE INDEX idx_enrollments_student_id ON public.enrollments(student_id);

-- -------------------------------------------------------------------
-- Attendance (per day, per enrollment)
-- -------------------------------------------------------------------
CREATE TABLE public.attendance (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id  UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  attendance_date DATE NOT NULL,
  status         TEXT NOT NULL, -- present/absent/late/excused
  marked_by      UUID REFERENCES public.users(id) ON DELETE SET NULL,
  remarks        TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT attendance_status_chk CHECK (status IN ('present','absent','late','excused')),
  UNIQUE (enrollment_id, attendance_date)
);

CREATE INDEX idx_attendance_date ON public.attendance(attendance_date);
CREATE INDEX idx_attendance_enrollment_date ON public.attendance(enrollment_id, attendance_date);

-- -------------------------------------------------------------------
-- Exams and Results
-- -------------------------------------------------------------------
CREATE TABLE public.exams (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,        -- e.g. "Midterm"
  academic_year TEXT NOT NULL,
  term          TEXT,                 -- e.g. "Term 1"
  starts_on     DATE,
  ends_on       DATE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT exams_dates_chk CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on),
  UNIQUE (name, academic_year, term)
);

CREATE INDEX idx_exams_year_term ON public.exams(academic_year, term);

CREATE TABLE public.exam_schedule (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id     UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
  section_id  UUID NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
  subject_id  UUID NOT NULL REFERENCES public.subjects(id) ON DELETE RESTRICT,
  exam_date   DATE NOT NULL,
  max_marks   NUMERIC(6,2) NOT NULL DEFAULT 100,
  pass_marks  NUMERIC(6,2) NOT NULL DEFAULT 35,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT exam_schedule_marks_chk CHECK (max_marks > 0 AND pass_marks >= 0 AND pass_marks <= max_marks),
  UNIQUE (exam_id, section_id, subject_id)
);

CREATE INDEX idx_exam_schedule_exam_section ON public.exam_schedule(exam_id, section_id);
CREATE INDEX idx_exam_schedule_exam_date ON public.exam_schedule(exam_date);

CREATE TABLE public.exam_results (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_schedule_id  UUID NOT NULL REFERENCES public.exam_schedule(id) ON DELETE CASCADE,
  enrollment_id     UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  marks_obtained    NUMERIC(6,2) NOT NULL,
  grade             TEXT,
  remarks           TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT exam_results_marks_chk CHECK (marks_obtained >= 0),
  UNIQUE (exam_schedule_id, enrollment_id)
);

CREATE INDEX idx_exam_results_enrollment ON public.exam_results(enrollment_id);

-- -------------------------------------------------------------------
-- Fees: structures, invoices, payments
-- -------------------------------------------------------------------
CREATE TABLE public.fee_structures (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL UNIQUE,  -- e.g. "Tuition"
  description   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.fee_invoices (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  academic_year TEXT NOT NULL,
  structure_id  UUID REFERENCES public.fee_structures(id) ON DELETE SET NULL,
  invoice_no    TEXT NOT NULL UNIQUE,
  due_date      DATE NOT NULL,
  amount        NUMERIC(12,2) NOT NULL,
  status        TEXT NOT NULL DEFAULT 'unpaid',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fee_invoices_amount_chk CHECK (amount >= 0),
  CONSTRAINT fee_invoices_status_chk CHECK (status IN ('unpaid','partially_paid','paid','void')),
  UNIQUE (student_id, academic_year, invoice_no)
);

CREATE INDEX idx_fee_invoices_student_year ON public.fee_invoices(student_id, academic_year);
CREATE INDEX idx_fee_invoices_status ON public.fee_invoices(status);

CREATE TABLE public.fee_payments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id   UUID NOT NULL REFERENCES public.fee_invoices(id) ON DELETE CASCADE,
  paid_on      DATE NOT NULL DEFAULT CURRENT_DATE,
  amount       NUMERIC(12,2) NOT NULL,
  method       TEXT NOT NULL DEFAULT 'cash',
  reference    TEXT,
  received_by  UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fee_payments_amount_chk CHECK (amount > 0),
  CONSTRAINT fee_payments_method_chk CHECK (method IN ('cash','card','bank_transfer','upi','cheque','other'))
);

CREATE INDEX idx_fee_payments_invoice_id ON public.fee_payments(invoice_id);
CREATE INDEX idx_fee_payments_paid_on ON public.fee_payments(paid_on);

-- -------------------------------------------------------------------
-- Timetable
-- -------------------------------------------------------------------
CREATE TABLE public.timetable_entries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id  UUID NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
  subject_id  UUID NOT NULL REFERENCES public.subjects(id) ON DELETE RESTRICT,
  teacher_id  UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
  day_of_week SMALLINT NOT NULL, -- 1=Mon ... 7=Sun
  start_time  TIME NOT NULL,
  end_time    TIME NOT NULL,
  room        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT timetable_day_chk CHECK (day_of_week BETWEEN 1 AND 7),
  CONSTRAINT timetable_time_chk CHECK (end_time > start_time),
  UNIQUE (section_id, day_of_week, start_time)
);

CREATE INDEX idx_timetable_section_day ON public.timetable_entries(section_id, day_of_week);
CREATE INDEX idx_timetable_teacher_day ON public.timetable_entries(teacher_id, day_of_week);

-- -------------------------------------------------------------------
-- Notices
-- -------------------------------------------------------------------
CREATE TABLE public.notices (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT NOT NULL,
  body         TEXT NOT NULL,
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at   TIMESTAMPTZ,
  created_by   UUID REFERENCES public.users(id) ON DELETE SET NULL,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT notices_expiry_chk CHECK (expires_at IS NULL OR expires_at >= published_at)
);

CREATE INDEX idx_notices_is_active ON public.notices(is_active);
CREATE INDEX idx_notices_published_at ON public.notices(published_at DESC);

CREATE TABLE public.notice_audience (
  notice_id   UUID NOT NULL REFERENCES public.notices(id) ON DELETE CASCADE,
  audience    TEXT NOT NULL, -- all, students, teachers, parents, admins, section
  section_id  UUID REFERENCES public.sections(id) ON DELETE CASCADE,
  PRIMARY KEY (notice_id, audience, section_id),
  CONSTRAINT notice_audience_chk CHECK (audience IN ('all','students','teachers','parents','admins','section')),
  CONSTRAINT notice_audience_section_chk CHECK (
    (audience = 'section' AND section_id IS NOT NULL) OR (audience <> 'section' AND section_id IS NULL)
  )
);

CREATE INDEX idx_notice_audience_audience ON public.notice_audience(audience);

-- -------------------------------------------------------------------
-- Audit / logging
-- -------------------------------------------------------------------
CREATE TABLE public.audit_log (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  action       TEXT NOT NULL,                 -- e.g. "student.create"
  entity_type  TEXT,                          -- e.g. "student"
  entity_id    UUID,
  details      JSONB,
  ip_address   INET,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_created_at ON public.audit_log(created_at DESC);
CREATE INDEX idx_audit_log_actor ON public.audit_log(actor_user_id);
CREATE INDEX idx_audit_log_entity ON public.audit_log(entity_type, entity_id);

-- -------------------------------------------------------------------
-- Seed Data (demo)
-- -------------------------------------------------------------------

-- Roles
INSERT INTO public.roles (name, description) VALUES
  ('admin', 'System administrator'),
  ('teacher', 'Teacher role'),
  ('student', 'Student role')
ON CONFLICT (name) DO NOTHING;

-- Permissions (minimal, extend as needed)
INSERT INTO public.permissions (code, description) VALUES
  ('users.read', 'Read users'),
  ('users.write', 'Create/update users'),
  ('students.read', 'Read students'),
  ('students.write', 'Create/update students'),
  ('teachers.read', 'Read teachers'),
  ('teachers.write', 'Create/update teachers'),
  ('attendance.read', 'Read attendance'),
  ('attendance.write', 'Mark attendance'),
  ('exams.read', 'Read exams'),
  ('exams.write', 'Manage exams'),
  ('fees.read', 'Read fee invoices/payments'),
  ('fees.write', 'Manage fee invoices/payments'),
  ('timetable.read', 'Read timetable'),
  ('timetable.write', 'Manage timetable'),
  ('notices.read', 'Read notices'),
  ('notices.write', 'Manage notices')
ON CONFLICT (code) DO NOTHING;

-- Role -> permissions
WITH r AS (
  SELECT id, name FROM public.roles WHERE name IN ('admin','teacher','student')
),
p AS (
  SELECT id, code FROM public.permissions
)
INSERT INTO public.role_permissions(role_id, permission_id)
SELECT r.id, p.id
FROM r
JOIN p ON (
  (r.name = 'admin') OR
  (r.name = 'teacher' AND p.code IN (
    'students.read','teachers.read','attendance.read','attendance.write','exams.read','exams.write','timetable.read','notices.read'
  )) OR
  (r.name = 'student' AND p.code IN (
    'students.read','attendance.read','exams.read','fees.read','timetable.read','notices.read'
  ))
)
ON CONFLICT DO NOTHING;

-- Users (password_hash values are placeholders for demo only)
-- In a real app, store a proper bcrypt/argon hash.
INSERT INTO public.users (email, username, password_hash, is_active, is_superuser) VALUES
  ('admin@school.test', 'admin', 'demo_hash_admin', TRUE, TRUE),
  ('teacher1@school.test', 'teacher1', 'demo_hash_teacher1', TRUE, FALSE),
  ('teacher2@school.test', 'teacher2', 'demo_hash_teacher2', TRUE, FALSE),
  ('student1@school.test', 'student1', 'demo_hash_student1', TRUE, FALSE),
  ('student2@school.test', 'student2', 'demo_hash_student2', TRUE, FALSE)
ON CONFLICT (email) DO NOTHING;

-- Assign roles to users
INSERT INTO public.user_roles(user_id, role_id)
SELECT u.id, r.id
FROM public.users u
JOIN public.roles r ON (
  (u.username = 'admin' AND r.name = 'admin') OR
  (u.username IN ('teacher1','teacher2') AND r.name = 'teacher') OR
  (u.username IN ('student1','student2') AND r.name = 'student')
)
ON CONFLICT DO NOTHING;

-- Teachers
INSERT INTO public.teachers (user_id, employee_no, first_name, last_name, email, phone, hire_date, status)
SELECT u.id, v.employee_no, v.first_name, v.last_name, u.email, v.phone, v.hire_date, 'active'
FROM (VALUES
  ('teacher1', 'T-1001', 'Asha', 'Kumar', '555-1001', DATE '2023-06-01'),
  ('teacher2', 'T-1002', 'Ravi', 'Singh', '555-1002', DATE '2024-01-15')
) AS v(username, employee_no, first_name, last_name, phone, hire_date)
JOIN public.users u ON u.username = v.username
ON CONFLICT (employee_no) DO NOTHING;

-- Students
INSERT INTO public.students (user_id, admission_no, first_name, last_name, dob, gender, phone, address, guardian_name, guardian_phone, status)
SELECT u.id, v.admission_no, v.first_name, v.last_name, v.dob, v.gender, v.phone, v.address, v.guardian_name, v.guardian_phone, 'active'
FROM (VALUES
  ('student1', 'S-2001', 'Neha', 'Patel', DATE '2012-03-10', 'F', '555-2001', '12 Park St', 'Meera Patel', '555-9001'),
  ('student2', 'S-2002', 'Arjun', 'Das',   DATE '2011-11-22', 'M', '555-2002', '88 Lake Rd', 'Suresh Das',  '555-9002')
) AS v(username, admission_no, first_name, last_name, dob, gender, phone, address, guardian_name, guardian_phone)
JOIN public.users u ON u.username = v.username
ON CONFLICT (admission_no) DO NOTHING;

-- Classes + Sections
INSERT INTO public.classes (name, sort_order) VALUES
  ('Grade 6', 6),
  ('Grade 7', 7)
ON CONFLICT (name) DO NOTHING;

-- Create sections (A for Grade 6 and Grade 7)
INSERT INTO public.sections (class_id, name, class_teacher_id, room)
SELECT c.id, 'A', t.id, CASE WHEN c.name = 'Grade 6' THEN 'R-601' ELSE 'R-701' END
FROM public.classes c
LEFT JOIN public.teachers t ON t.employee_no = CASE WHEN c.name = 'Grade 6' THEN 'T-1001' ELSE 'T-1002' END
WHERE c.name IN ('Grade 6','Grade 7')
ON CONFLICT (class_id, name) DO NOTHING;

-- Subjects
INSERT INTO public.subjects (code, name) VALUES
  ('MATH', 'Mathematics'),
  ('SCI', 'Science'),
  ('ENG', 'English')
ON CONFLICT (code) DO NOTHING;

-- Offer all subjects in both sections
INSERT INTO public.section_subjects (section_id, subject_id)
SELECT s.id, sub.id
FROM public.sections s
JOIN public.classes c ON c.id = s.class_id AND c.name IN ('Grade 6','Grade 7')
JOIN public.subjects sub ON sub.code IN ('MATH','SCI','ENG')
ON CONFLICT DO NOTHING;

-- Teacher assignments
-- Teacher1 teaches MATH+ENG to Grade 6 A; Teacher2 teaches SCI to Grade 6 A and Grade 7 A (demo)
INSERT INTO public.teacher_subjects (teacher_id, subject_id, section_id)
SELECT t.id, sub.id, s.id
FROM public.teachers t
JOIN public.subjects sub ON (
  (t.employee_no = 'T-1001' AND sub.code IN ('MATH','ENG')) OR
  (t.employee_no = 'T-1002' AND sub.code IN ('SCI'))
)
JOIN public.sections s ON (
  (t.employee_no = 'T-1001' AND s.room = 'R-601') OR
  (t.employee_no = 'T-1002' AND s.room IN ('R-601','R-701'))
)
ON CONFLICT DO NOTHING;

-- Enroll students into Grade 6 A for academic year
INSERT INTO public.enrollments (student_id, section_id, academic_year, roll_no, start_date, status)
SELECT st.id, s.id, '2025-2026',
       CASE WHEN st.admission_no = 'S-2001' THEN 1 ELSE 2 END,
       DATE '2025-06-01', 'active'
FROM public.students st
JOIN public.sections s ON s.room = 'R-601'
WHERE st.admission_no IN ('S-2001','S-2002')
ON CONFLICT (student_id, academic_year) DO NOTHING;

-- Attendance (two dates)
INSERT INTO public.attendance (enrollment_id, attendance_date, status, marked_by, remarks)
SELECT e.id, DATE '2025-06-10',
       CASE WHEN st.admission_no = 'S-2001' THEN 'present' ELSE 'absent' END,
       u.id,
       CASE WHEN st.admission_no = 'S-2002' THEN 'Sick leave' ELSE NULL END
FROM public.enrollments e
JOIN public.students st ON st.id = e.student_id
JOIN public.users u ON u.username = 'teacher1'
WHERE e.academic_year = '2025-2026'
ON CONFLICT (enrollment_id, attendance_date) DO NOTHING;

INSERT INTO public.attendance (enrollment_id, attendance_date, status, marked_by)
SELECT e.id, DATE '2025-06-11', 'present', u.id
FROM public.enrollments e
JOIN public.users u ON u.username = 'teacher1'
WHERE e.academic_year = '2025-2026'
ON CONFLICT (enrollment_id, attendance_date) DO NOTHING;

-- Exams + schedule + results
INSERT INTO public.exams (name, academic_year, term, starts_on, ends_on)
VALUES ('Midterm', '2025-2026', 'Term 1', DATE '2025-09-10', DATE '2025-09-20')
ON CONFLICT (name, academic_year, term) DO NOTHING;

-- Schedule: Grade 6 A subjects on different days
INSERT INTO public.exam_schedule (exam_id, section_id, subject_id, exam_date, max_marks, pass_marks)
SELECT ex.id, sec.id, sub.id,
       CASE sub.code WHEN 'MATH' THEN DATE '2025-09-11'
                     WHEN 'ENG'  THEN DATE '2025-09-13'
                     ELSE DATE '2025-09-15' END,
       100, 35
FROM public.exams ex
JOIN public.sections sec ON sec.room = 'R-601'
JOIN public.subjects sub ON sub.code IN ('MATH','ENG','SCI')
WHERE ex.name = 'Midterm' AND ex.academic_year = '2025-2026' AND ex.term = 'Term 1'
ON CONFLICT (exam_id, section_id, subject_id) DO NOTHING;

-- Results for enrolled students
INSERT INTO public.exam_results (exam_schedule_id, enrollment_id, marks_obtained, grade)
SELECT es.id, e.id,
       CASE sub.code
         WHEN 'MATH' THEN CASE WHEN st.admission_no = 'S-2001' THEN 92 ELSE 58 END
         WHEN 'ENG'  THEN CASE WHEN st.admission_no = 'S-2001' THEN 88 ELSE 61 END
         ELSE              CASE WHEN st.admission_no = 'S-2001' THEN 90 ELSE 55 END
       END AS marks_obtained,
       NULL
FROM public.exam_schedule es
JOIN public.subjects sub ON sub.id = es.subject_id
JOIN public.enrollments e ON e.section_id = es.section_id AND e.academic_year = '2025-2026'
JOIN public.students st ON st.id = e.student_id
JOIN public.exams ex ON ex.id = es.exam_id AND ex.name='Midterm' AND ex.academic_year='2025-2026' AND ex.term='Term 1'
ON CONFLICT (exam_schedule_id, enrollment_id) DO NOTHING;

-- Fees
INSERT INTO public.fee_structures (name, description)
VALUES ('Tuition', 'Monthly tuition fees')
ON CONFLICT (name) DO NOTHING;

-- Invoices: one per student (demo)
INSERT INTO public.fee_invoices (student_id, academic_year, structure_id, invoice_no, due_date, amount, status)
SELECT st.id, '2025-2026',
       fs.id,
       'INV-' || st.admission_no || '-001',
       DATE '2025-06-30',
       2500.00,
       'unpaid'
FROM public.students st
JOIN public.fee_structures fs ON fs.name='Tuition'
WHERE st.admission_no IN ('S-2001','S-2002')
ON CONFLICT (invoice_no) DO NOTHING;

-- Payment: student1 pays partial
INSERT INTO public.fee_payments (invoice_id, paid_on, amount, method, reference, received_by)
SELECT fi.id, DATE '2025-06-20', 1500.00, 'cash', 'RCPT-0001', u.id
FROM public.fee_invoices fi
JOIN public.users u ON u.username='admin'
WHERE fi.invoice_no = 'INV-S-2001-001'
ON CONFLICT DO NOTHING;

-- Update invoice statuses based on payments (demo-friendly)
-- unpaid -> partially_paid -> paid
WITH paid AS (
  SELECT invoice_id, SUM(amount) AS total_paid
  FROM public.fee_payments
  GROUP BY invoice_id
)
UPDATE public.fee_invoices i
SET status = CASE
  WHEN COALESCE(p.total_paid, 0) = 0 THEN 'unpaid'
  WHEN COALESCE(p.total_paid, 0) >= i.amount THEN 'paid'
  ELSE 'partially_paid'
END,
updated_at = now()
FROM paid p
WHERE i.id = p.invoice_id;

-- Timetable (Grade 6 A)
INSERT INTO public.timetable_entries (section_id, subject_id, teacher_id, day_of_week, start_time, end_time, room)
SELECT sec.id, sub.id,
       (SELECT t.id FROM public.teachers t WHERE t.employee_no = CASE sub.code WHEN 'SCI' THEN 'T-1002' ELSE 'T-1001' END),
       1, TIME '09:00', TIME '09:45', sec.room
FROM public.sections sec
JOIN public.subjects sub ON sub.code IN ('MATH','ENG','SCI')
WHERE sec.room='R-601'
ON CONFLICT (section_id, day_of_week, start_time) DO NOTHING;

-- Notices
INSERT INTO public.notices (title, body, published_at, created_by, is_active)
SELECT
  'Welcome to the new academic year',
  'School reopens on 2025-06-01. Please check the timetable and fee invoices.',
  now(),
  u.id,
  TRUE
FROM public.users u
WHERE u.username='admin'
ON CONFLICT DO NOTHING;

INSERT INTO public.notice_audience (notice_id, audience, section_id)
SELECT n.id, 'all', NULL
FROM public.notices n
WHERE n.title='Welcome to the new academic year'
ON CONFLICT DO NOTHING;

-- Audit samples
INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, details)
SELECT u.id, 'seed.run', 'system', NULL, jsonb_build_object('note','Initial demo seed executed')
FROM public.users u
WHERE u.username='admin'
ON CONFLICT DO NOTHING;

COMMIT;
