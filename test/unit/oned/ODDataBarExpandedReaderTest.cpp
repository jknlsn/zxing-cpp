/*
* Copyright 2026 ZXing authors
*/
// SPDX-License-Identifier: Apache-2.0

#include "oned/ODDataBarCommon.h"

#include "gtest/gtest.h"

#include <map>
#include <vector>

namespace ZXing::OneD {
using Pairs = std::vector<DataBar::Pair>;
using PairMap = std::map<int, Pairs>;
Pairs FindValidSequence(PairMap& all);
void RemovePairs(PairMap& all, const Pairs& pairs);
}

using namespace ZXing::OneD;

TEST(ODDataBarExpandedReaderTest, RequiresRepeatedPairsAfterFirst)
{
	// Finder sequence [A, -A], checksum 10 = 1 + 4 + 5.
	// The first pair is intentionally not subject to the repeat threshold.
	PairMap all = {{1, {{{10, 0}, {1, 1}, 1}}}, {-1, {{{20, 4}, {30, 5}, -1}}}};
	EXPECT_TRUE(FindValidSequence(all).empty());
	all[-1][0].count = 2;
	EXPECT_EQ(FindValidSequence(all).size(), 2u);
}

TEST(ODDataBarExpandedReaderTest, SelectsRepeatedCandidateAfterRemoval)
{
	PairMap all = {{1, {{{10, 0}, {1, 1}, 1}}},
				  {-1, {{{20, 4}, {30, 5}, -1}, {{21, 4}, {30, 5}, -1}}}};
	all[1][0].count = 2;
	for (auto& pair : all[-1])
		pair.count = 2;

	auto first = FindValidSequence(all);
	ASSERT_EQ(first.size(), 2u);
	EXPECT_EQ(first.back().left.value, 20);
	RemovePairs(all, first);

	// Removal decrements only the selected candidate: [2, 2] becomes [1, 2].
	ASSERT_EQ(all[-1].size(), 2u);
	EXPECT_EQ(all[-1][0].count, 1);
	EXPECT_EQ(all[-1][1].count, 2);
	auto second = FindValidSequence(all);
	ASSERT_EQ(second.size(), 2u);
	EXPECT_EQ(second.back(), all[-1][1]);

	RemovePairs(all, second);
	EXPECT_TRUE(FindValidSequence(all).empty()); // Both candidates now have count 1.
}
