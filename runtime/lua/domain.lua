-- Lua_of_ocaml runtime support
-- http://www.ocsigen.org/js_of_ocaml/
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, with linking exception;
-- either version 2.1 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

-- OCaml 5.0+ Domain and Atomic Operations
--
-- Lua is single-threaded, so atomic operations don't need actual atomic semantics.
-- These are simple implementations that provide the correct interface.

--Provides: caml_domain_dls
caml_domain_dls = {tag = 0}

--Provides: caml_domain_dls_set
--Requires: caml_domain_dls
function caml_domain_dls_set(a)
  caml_domain_dls = a
end

--Provides: caml_domain_dls_compare_and_set
--Requires: caml_domain_dls
function caml_domain_dls_compare_and_set(old, n)
  if caml_domain_dls ~= old then
    return 0
  end
  caml_domain_dls = n
  return 1
end

--Provides: caml_domain_dls_get
--Requires: caml_domain_dls
function caml_domain_dls_get(_unit)
  return caml_domain_dls
end

--Provides: caml_atomic_load
function caml_atomic_load(ref)
  -- Atomic references are blocks with tag 0: {0, value}
  -- With new array representation, ref[1] = tag, ref[2] = value
  return ref[2]
end

--Provides: caml_atomic_load_field
function caml_atomic_load_field(b, i)
  -- Fields are at index i+2 (1-indexed array, tag at index 1)
  return b[i + 2]
end

--Provides: caml_atomic_cas
function caml_atomic_cas(ref, o, n)
  -- Compare-and-swap on ref[2] (the value, not the tag)
  if ref[2] == o then
    ref[2] = n
    return 1
  end
  return 0
end

--Provides: caml_atomic_cas_field
function caml_atomic_cas_field(b, i, o, n)
  -- Field at index i+2 (skip tag at index 1)
  if b[i + 2] == o then
    b[i + 2] = n
    return 1
  end
  return 0
end

--Provides: caml_atomic_fetch_add
function caml_atomic_fetch_add(ref, i)
  -- Fetch-and-add on ref[2] (the value)
  local old = ref[2]
  ref[2] = ref[2] + i
  return old
end

--Provides: caml_atomic_fetch_add_field
function caml_atomic_fetch_add_field(b, i, n)
  -- Field at index i+2
  local old = b[i + 2]
  b[i + 2] = b[i + 2] + n
  return old
end

--Provides: caml_atomic_exchange
function caml_atomic_exchange(ref, v)
  -- Exchange value at ref[2]
  local r = ref[2]
  ref[2] = v
  return r
end

--Provides: caml_atomic_exchange_field
function caml_atomic_exchange_field(b, i, v)
  -- Field at index i+2
  local r = b[i + 2]
  b[i + 2] = v
  return r
end

--Provides: caml_atomic_make_contended
function caml_atomic_make_contended(a)
  return {tag = 0, a}
end

--Provides: caml_ml_domain_unique_token
caml_ml_domain_unique_token = {tag = 0}

--Provides: caml_ml_domain_id
function caml_ml_domain_id(_unit)
  return 0
end

--Provides: caml_ml_domain_spawn
function caml_ml_domain_spawn(_f, _term)
  error("Domains not supported in Lua (single-threaded)")
end

--Provides: caml_ml_domain_join
function caml_ml_domain_join(_domain)
  error("Domains not supported in Lua (single-threaded)")
end

--Provides: caml_ml_domain_cpu_relax
function caml_ml_domain_cpu_relax()
  -- No-op in single-threaded environment
end

--Provides: caml_ml_domain_set_name
function caml_ml_domain_set_name(_name)
  -- No-op in single-threaded environment
end

--Provides: caml_ml_domain_recommended_domain_count
function caml_ml_domain_recommended_domain_count(_unit)
  return 1
end
