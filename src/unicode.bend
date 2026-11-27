import Base

def unicode_ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def unicode_punct_or_symbol_code(+x: U32) -> Bool:
    unicode_ifs(Bool, U32.is_lt(x, 43124),
      u =>
        unicode_ifs(Bool, U32.is_lt(x, 6464),
          u =>
            unicode_ifs(Bool, U32.is_lt(x, 2096),
              u =>
                unicode_ifs(Bool, U32.is_lt(x, 903),
                  u =>
                    unicode_ifs(Bool, U32.is_lt(x, 191),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 171),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 91),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 58),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 33),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 47),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 64),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 96),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 161),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 123),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 126),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 169),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 172),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 182),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 180),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 174),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 177),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 180),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 184),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 187),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 187),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 191),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 749),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 706),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 247),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 215),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 215),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 247),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 709),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 741),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 722),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 735),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 747),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 749),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 894),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 885),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 751),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 767),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 885),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 894),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 900),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 901),
                                    v => True{},
                                    v =>
                                    False{}))))))))
                  u => unicode_ifs(Bool, U32.is_le(x, 903),
                    v => True{},
                    v =>
                    unicode_ifs(Bool, U32.is_lt(x, 1542),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 1470),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 1370),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 1154),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 1014),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 1014),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 1154),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 1375),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 1421),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 1417),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 1418),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 1423),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 1470),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 1478),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 1475),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 1472),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 1472),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 1475),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 1478),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 1523),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 1524),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 1551),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 1769),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 1642),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 1565),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 1563),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 1563),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 1567),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 1645),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 1758),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 1748),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 1748),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 1758),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 1769),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 2038),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 1792),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 1789),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 1790),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 1805),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 2041),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 2046),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 2047),
                                    v => True{},
                                    v =>
                                    False{}))))))))))
              u => unicode_ifs(Bool, U32.is_le(x, 2110),
                v => True{},
                v =>
                unicode_ifs(Bool, U32.is_lt(x, 3866),
                  u =>
                    unicode_ifs(Bool, U32.is_lt(x, 3059),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 2554),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 2404),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 2184),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 2142),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 2142),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 2184),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 2405),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 2546),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 2416),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 2416),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 2547),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 2555),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 2800),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 2678),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 2557),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 2557),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 2678),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 2801),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 2928),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 2928),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 3066),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 3572),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 3204),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 3199),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 3191),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 3191),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 3199),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 3204),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 3449),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 3407),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 3407),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 3449),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 3572),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 3674),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 3663),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 3647),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 3647),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 3663),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 3675),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 3841),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 3863),
                                    v => True{},
                                    v =>
                                    False{}))))))))
                  u => unicode_ifs(Bool, U32.is_le(x, 3871),
                    v => True{},
                    v =>
                    unicode_ifs(Bool, U32.is_lt(x, 4347),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 4030),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 3896),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 3894),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 3892),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 3892),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 3894),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 3896),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 3973),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 3898),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 3901),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 3973),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 4037),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 4170),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 4046),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 4039),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 4044),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 4058),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 4175),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 4254),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 4255),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 4347),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 5867),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 5120),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 5008),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 4960),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 4968),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 5017),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 5120),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 5787),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 5741),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 5742),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 5788),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 5869),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 6104),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 6100),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 5941),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 5942),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 6102),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 6107),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 6144),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 6154),
                                    v => True{},
                                    v =>
                                    False{}))))))))))))
          u => unicode_ifs(Bool, U32.is_le(x, 6464),
            v => True{},
            v =>
            unicode_ifs(Bool, U32.is_lt(x, 10132),
              u =>
                unicode_ifs(Bool, U32.is_lt(x, 8314),
                  u =>
                    unicode_ifs(Bool, U32.is_lt(x, 7294),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 6990),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 6686),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 6622),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 6468),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 6469),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 6655),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 6687),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 6824),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 6816),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 6822),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 6829),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 6991),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 7164),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 7028),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 7002),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 7018),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 7039),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 7167),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 7227),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 7231),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 7295),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 8157),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 8125),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 7379),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 7360),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 7367),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 7379),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 8125),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 8141),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 8127),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 8129),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 8143),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 8159),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 8208),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 8189),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 8173),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 8175),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 8190),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 8231),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 8240),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 8286),
                                    v => True{},
                                    v =>
                                    False{}))))))))
                  u => unicode_ifs(Bool, U32.is_le(x, 8318),
                    v => True{},
                    v =>
                    unicode_ifs(Bool, U32.is_lt(x, 8489),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 8468),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 8448),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 8352),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 8330),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 8334),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 8384),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 8449),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 8456),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 8451),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 8454),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 8457),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 8468),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 8485),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 8478),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 8470),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 8472),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 8483),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 8485),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 8487),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 8487),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 8489),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 8586),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 8512),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 8506),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 8494),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 8494),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 8507),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 8516),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 8527),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 8522),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 8525),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 8527),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 8587),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 9372),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 9280),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 8592),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 9257),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 9290),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 9449),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 9472),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 10101),
                                    v => True{},
                                    v =>
                                    False{}))))))))))
              u => unicode_ifs(Bool, U32.is_le(x, 11123),
                v => True{},
                v =>
                unicode_ifs(Bool, U32.is_lt(x, 12694),
                  u =>
                    unicode_ifs(Bool, U32.is_lt(x, 12032),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 11632),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 11493),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 11159),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 11126),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 11157),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 11263),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 11498),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 11518),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 11513),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 11516),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 11519),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 11632),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 11904),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 11824),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 11776),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 11822),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 11869),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 11929),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 11931),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 12019),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 12245),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 12349),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 12296),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 12289),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 12272),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 12287),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 12292),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 12320),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 12342),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 12336),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 12336),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 12343),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 12351),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 12539),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 12448),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 12443),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 12444),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 12448),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 12539),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 12688),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 12689),
                                    v => True{},
                                    v =>
                                    False{}))))))))
                  u => unicode_ifs(Bool, U32.is_le(x, 12703),
                    v => True{},
                    v =>
                    unicode_ifs(Bool, U32.is_lt(x, 42238),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 12896),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 12800),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 12783),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 12736),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 12773),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 12783),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 12830),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 12880),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 12842),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 12871),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 12880),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 12927),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 19904),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 12992),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 12938),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 12976),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 13311),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 19967),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 42128),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 42182),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 42239),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 42752),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 42622),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 42611),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 42509),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 42511),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 42611),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 42622),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 42738),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 42743),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 42774),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 43048),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 42889),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 42784),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 42785),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 42890),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 43051),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 43062),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 43065),
                                    v => True{},
                                    v =>
                                    False{}))))))))))))))
      u => unicode_ifs(Bool, U32.is_le(x, 43127),
        v => True{},
        v =>
        unicode_ifs(Bool, U32.is_lt(x, 73463),
          u =>
            unicode_ifs(Bool, U32.is_lt(x, 67903),
              u =>
                unicode_ifs(Bool, U32.is_lt(x, 65108),
                  u =>
                    unicode_ifs(Bool, U32.is_lt(x, 43760),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 43457),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 43260),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 43256),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 43214),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 43215),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 43258),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 43260),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 43359),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 43310),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 43311),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 43359),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 43469),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 43639),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 43612),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 43486),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 43487),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 43615),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 43641),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 43742),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 43743),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 43761),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 64830),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 44011),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 43882),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 43867),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 43867),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 43883),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 44011),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 64434),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 64297),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 64297),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 64450),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 64847),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 65040),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 65020),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 64975),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 64975),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 65023),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 65049),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 65072),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 65106),
                                    v => True{},
                                    v =>
                                    False{}))))))))
                  u => unicode_ifs(Bool, U32.is_le(x, 65126),
                    v => True{},
                    v =>
                    unicode_ifs(Bool, U32.is_lt(x, 65913),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 65504),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 65306),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 65281),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 65128),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 65131),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 65295),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 65312),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 65371),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 65339),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 65344),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 65381),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 65510),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 65792),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 65532),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 65512),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 65518),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 65533),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 65794),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 65847),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 65855),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 65929),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 66512),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 65952),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 65936),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 65932),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 65934),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 65948),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 65952),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 66463),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 66000),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 66044),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 66463),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 66512),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 67703),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 67671),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 66927),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 66927),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 67671),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 67704),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 67871),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 67871),
                                    v => True{},
                                    v =>
                                    False{}))))))))))
              u => unicode_ifs(Bool, U32.is_le(x, 67903),
                v => True{},
                v =>
                unicode_ifs(Bool, U32.is_lt(x, 70313),
                  u =>
                    unicode_ifs(Bool, U32.is_lt(x, 69510),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 68505),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 68296),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 68223),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 68176),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 68184),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 68223),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 68296),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 68409),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 68336),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 68342),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 68415),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 68508),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 69293),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 69006),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 68974),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 68974),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 69007),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 69293),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 69461),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 69465),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 69513),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 70085),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 69822),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 69819),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 69703),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 69709),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 69820),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 69825),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 70004),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 69952),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 69955),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 70005),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 70088),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 70109),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 70107),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 70093),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 70093),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 70107),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 70111),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 70200),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 70205),
                                    v => True{},
                                    v =>
                                    False{}))))))))
                  u => unicode_ifs(Bool, U32.is_le(x, 70313),
                    v => True{},
                    v =>
                    unicode_ifs(Bool, U32.is_lt(x, 71484),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 70854),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 70731),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 70615),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 70612),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 70613),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 70616),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 70735),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 70749),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 70746),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 70747),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 70749),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 70854),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 71264),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 71233),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 71105),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 71127),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 71235),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 71276),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 71353),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 71353),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 71487),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 72350),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 72162),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 72004),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 71739),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 71739),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 72006),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 72162),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 72346),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 72255),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 72262),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 72348),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 72354),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 72769),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 72673),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 72448),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 72457),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 72673),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 72773),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 72816),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 72817),
                                    v => True{},
                                    v =>
                                    False{}))))))))))))
          u => unicode_ifs(Bool, U32.is_le(x, 73464),
            v => True{},
            v =>
            unicode_ifs(Bool, U32.is_lt(x, 123647),
              u =>
                unicode_ifs(Bool, U32.is_lt(x, 119171),
                  u =>
                    unicode_ifs(Bool, U32.is_lt(x, 93847),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 92782),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 73727),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 73685),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 73539),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 73551),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 73713),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 73727),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 77809),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 74864),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 74868),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 77810),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 92783),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 92996),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 92983),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 92917),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 92917),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 92991),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 92997),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 93549),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 93551),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 93850),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 118608),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 113823),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 113820),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 94178),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 94178),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 113820),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 113823),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 118016),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 117760),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 117999),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 118451),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 118723),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 119081),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 119040),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 118784),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 119029),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 119078),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 119140),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 119146),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 119148),
                                    v => True{},
                                    v =>
                                    False{}))))))))
                  u => unicode_ifs(Bool, U32.is_le(x, 119172),
                    v => True{},
                    v =>
                    unicode_ifs(Bool, U32.is_lt(x, 120655),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 120513),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 119296),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 119214),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 119180),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 119209),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 119274),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 119361),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 119552),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 119365),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 119365),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 119638),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 120513),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 120597),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 120571),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 120539),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 120539),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 120571),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 120597),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 120629),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 120629),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 120655),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 121399),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 120745),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 120713),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 120687),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 120687),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 120713),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 120745),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 120832),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 120771),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 120771),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 121343),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 121402),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 121477),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 121462),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 121453),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 121460),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 121475),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 121483),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 123215),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 123215),
                                    v => True{},
                                    v =>
                                    False{}))))))))))
              u => unicode_ifs(Bool, U32.is_le(x, 123647),
                v => True{},
                v =>
                unicode_ifs(Bool, U32.is_lt(x, 128768),
                  u =>
                    unicode_ifs(Bool, U32.is_lt(x, 127169),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 126704),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 126124),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 125278),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 124415),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 124415),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 125279),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 126124),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 126254),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 126128),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 126128),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 126254),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 126705),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 127136),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 127024),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 126976),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 127019),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 127123),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 127150),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 127153),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 127167),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 127183),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 127568),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 127462),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 127245),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 127185),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 127221),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 127405),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 127490),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 127552),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 127504),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 127547),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 127560),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 127569),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 128732),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 127744),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 127584),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 127589),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 128727),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 128748),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 128752),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 128764),
                                    v => True{},
                                    v =>
                                    False{}))))))))
                  u => unicode_ifs(Bool, U32.is_le(x, 128886),
                    v => True{},
                    v =>
                    unicode_ifs(Bool, U32.is_lt(x, 129280),
                      u =>
                        unicode_ifs(Bool, U32.is_lt(x, 129104),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 129008),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 128992),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 128891),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 128985),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 129003),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 129008),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 129040),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 129024),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 129035),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 129095),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 129113),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 129200),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 129168),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 129120),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 129159),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 129197),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 129211),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 129216),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 129217),
                                    v => True{},
                                    v =>
                                    False{}))))))
                      u => unicode_ifs(Bool, U32.is_le(x, 129619),
                        v => True{},
                        v =>
                        unicode_ifs(Bool, U32.is_lt(x, 129742),
                          u =>
                            unicode_ifs(Bool, U32.is_lt(x, 129664),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 129648),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 129632),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 129645),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 129660),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 129673),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 129679),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 129734),
                                    v => True{},
                                    v =>
                                    False{}))))
                          u => unicode_ifs(Bool, U32.is_le(x, 129756),
                            v => True{},
                            v =>
                            unicode_ifs(Bool, U32.is_lt(x, 129792),
                              u =>
                                unicode_ifs(Bool, U32.is_lt(x, 129776),
                                  u =>
                                    unicode_ifs(Bool, U32.is_lt(x, 129759),
                                      u =>
                                        False{}
                                      u => unicode_ifs(Bool, U32.is_le(x, 129769),
                                        v => True{},
                                        v =>
                                        False{}))
                                  u => unicode_ifs(Bool, U32.is_le(x, 129784),
                                    v => True{},
                                    v =>
                                    False{}))
                              u => unicode_ifs(Bool, U32.is_le(x, 129938),
                                v => True{},
                                v =>
                                unicode_ifs(Bool, U32.is_lt(x, 129940),
                                  u =>
                                    False{}
                                  u => unicode_ifs(Bool, U32.is_le(x, 130031),
                                    v => True{},
                                    v =>
                                    False{}))))))))))))))))

def unicode_punct_or_symbol(+c: Char) -> Bool:
  unicode_punct_or_symbol_code(Char.to_u32(c))
