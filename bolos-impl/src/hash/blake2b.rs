/*******************************************************************************
*   (c) 2021 Zondax GmbH
*
*  Licensed under the Apache License, Version 2.0 (the "License");
*  you may not use this file except in compliance with the License.
*  You may obtain a copy of the License at
*
*      http://www.apache.org/licenses/LICENSE-2.0
*
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
********************************************************************************/
#![allow(unused_imports)]

use crate::raw::{cx_blake2b_t, cx_hash_t, cx_md_t};
use crate::{errors::catch, Error};

use super::CxHash;

use core::{mem::MaybeUninit, ptr::addr_of_mut};

#[repr(transparent)]
pub struct Blake2b<const S: usize> {
    state: cx_blake2b_t,
}

impl<const S: usize> Blake2b<S> {
    #[inline(never)]
    pub fn new() -> Result<Self, Error> {
        zemu_sys::zemu_log_stack("Blake2b::new\x00");
        let mut this = Self {
            state: Default::default(),
        };

        Self::init_state(&mut this.state)?;

        Ok(this)
    }

    pub fn new_gce(loc: &mut MaybeUninit<Self>) -> Result<(), Error> {
        let state = unsafe { addr_of_mut!((*loc.as_mut_ptr()).state) };

        Self::init_state(state)
    }

    fn init_state(state: *mut cx_blake2b_t) -> Result<(), Error> {
        cfg_if! {
            if #[cfg(nanox)] {
                let might_throw = || unsafe {
                    crate::raw::cx_blake2b_init(state, (S * 8) as u32);
                };

                catch(might_throw)?;
            } else if #[cfg(nanos)] {
                let r = unsafe {
                    crate::raw::cx_blake2b_init_no_throw(
                        state,
                        (S * 8) as u32
                    )
                };

                match r {
                    0 => {},
                    err => return Err(err.into()),
                }
            } else {
                unimplemented!("blake2b init called in non bolos")
            }
        }

        Ok(())
    }
}

impl<const S: usize> CxHash<S> for Blake2b<S> {
    fn cx_init_hasher() -> Result<Self, Error> {
        Self::new()
    }

    fn cx_init_hasher_gce(loc: &mut MaybeUninit<Self>) -> Result<(), super::Error> {
        Self::new_gce(loc)
    }

    fn cx_reset(&mut self) -> Result<(), Error> {
        Self::init_state(&mut self.state)
    }

    fn cx_header(&mut self) -> &mut cx_hash_t {
        &mut self.state.header
    }

    fn cx_id() -> cx_md_t {
        crate::raw::cx_md_e_CX_BLAKE2B
    }
}
