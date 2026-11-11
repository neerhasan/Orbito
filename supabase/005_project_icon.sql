-- A project has an icon, picked from a fixed list in the app
-- (`ProjectIcons` in lib/ui/ember.dart). The name of the icon is saved,
-- for example 'folder'. Applied on the server as migration `project_icon`.
alter table public.projects add column if not exists icon text not null default 'folder';
