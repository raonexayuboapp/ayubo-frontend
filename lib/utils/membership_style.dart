import 'package:flutter/material.dart';

/// Tier colours by rank (the cheapest plan first): green, blue, purple, amber, then around again.
/// The schema has no colour column, so the rank decides. If the web shop stores a badge, this is the one place to change.
const _tierColors = [Color(0xFF2E9E5B), Color(0xFF2F7FD1), Color(0xFF7B4FC9), Color(0xFFD99A00)];

Color tierColor(int rank) => _tierColors[rank % _tierColors.length];