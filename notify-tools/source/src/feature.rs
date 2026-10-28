use std::ops::Range;
use crate::{Result, image::{Image, References, Symbols}, progress::Progress};

#[derive(Clone)]
pub struct Edit { pub range: Range<usize>, pub bytes: Vec<u8> }
pub struct Mode<T = Vec<Edit>> { pub id: &'static str, pub name: &'static str, pub edits: T }
pub struct Feature { pub id: &'static str, pub name: &'static str, pub description: &'static str, pub targets: &'static [Target] }
pub struct Target { pub file: Option<&'static str>, pub find: fn(&Image<'_>, &Progress) -> Result<Symbols>, pub scan: fn(Symbols) -> Box<dyn Analysis> }
pub trait Analysis {
    fn visit(&mut self, image: &Image<'_>, function: &Range<u64>, references: &References, progress: &Progress) -> Result<Vec<Edit>>;
    fn finish(self: Box<Self>, image: &Image<'_>, references: &References, progress: &Progress) -> Result<Vec<Mode>>;
}
