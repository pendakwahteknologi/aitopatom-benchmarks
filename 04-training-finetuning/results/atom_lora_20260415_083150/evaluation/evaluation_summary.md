# Evaluation Summary

- **Machine**: atom
- **Mode**: lora
- **Model**: meta-llama/Llama-3.1-8B
- **Questions**: 80
- **Temperature**: 0.0
- **Max new tokens**: 256

## Overall Metrics

| Metric | Baseline | Fine-tuned | Delta |
|--------|----------|------------|-------|
| rouge_l | 0.2597 | 0.1466 | -0.1131 |
| bleu | 0.0674 | 0.0372 | -0.0302 |
| exact_match | 0.0125 | 0.0000 | -0.0125 |
| normalized_match | 0.4059 | 0.5387 | +0.1328 |
| prediction_length | 118.0000 | 198.1000 | +80.1000 |
| latency_sec | 11.2289 | 19.7312 | +8.5023 |

## Category Metrics

### brainstorming

| Metric | Baseline | Fine-tuned |
|--------|----------|------------|
| rouge_l | 0.1038 | 0.0934 |
| bleu | 0.0148 | 0.0041 |

### classification

| Metric | Baseline | Fine-tuned |
|--------|----------|------------|
| rouge_l | 0.3756 | 0.1441 |
| bleu | 0.0670 | 0.0422 |

### closed_qa

| Metric | Baseline | Fine-tuned |
|--------|----------|------------|
| rouge_l | 0.4401 | 0.1406 |
| bleu | 0.1722 | 0.0380 |

### creative_writing

| Metric | Baseline | Fine-tuned |
|--------|----------|------------|
| rouge_l | 0.1329 | 0.1564 |
| bleu | 0.0160 | 0.0164 |

### general_qa

| Metric | Baseline | Fine-tuned |
|--------|----------|------------|
| rouge_l | 0.1399 | 0.1310 |
| bleu | 0.0093 | 0.0140 |

### information_extraction

| Metric | Baseline | Fine-tuned |
|--------|----------|------------|
| rouge_l | 0.4510 | 0.1225 |
| bleu | 0.1138 | 0.0404 |

### open_qa

| Metric | Baseline | Fine-tuned |
|--------|----------|------------|
| rouge_l | 0.1380 | 0.1021 |
| bleu | 0.0226 | 0.0247 |

### summarization

| Metric | Baseline | Fine-tuned |
|--------|----------|------------|
| rouge_l | 0.2962 | 0.2828 |
| bleu | 0.1237 | 0.1179 |

## Sample Comparisons

**[brainstorming]** Give me three recipes from different cuisines that I can make with potatoes and chicken
- Reference: You could make potato dumplings in a chicken broth, which comes from German cuisine. Another recipe is mashed potatoes and fried chicken from the Amer
- Baseline: * **Recipe 1:** [Chicken and Potato Curry](https://www.bbcgoodfood.com/recipes/chicken-potato-curry)
* **Recipe 2:** [Chicken and Potato Casserole](ht
- Fine-tuned: 1. Chicken Tikka Masala - Indian
2. Chicken and Potatoes - American
3. Chicken and Potatoes - French
4. Chicken and Potatoes - Italian
5. Chicken and 

**[brainstorming]** Give me multiple modes of transport to get to Australia
- Reference: Fly by plane, take a boat or cruise ship, swim, paddle board, kayak, sail
- Baseline: ```bash
$ python3 main.py
Enter a mode of transport: car
Enter a mode of transport: plane
Enter a mode of transport: boat
Enter a mode of transport: t
- Fine-tuned: You can get to Australia by plane, boat, or car. You can also get there by train, but it is a very long journey. You can also get there by bike, but i

**[brainstorming]** What are the primary ingredients and spices that go into Greek cooking?
- Reference: 1) Salt
2) Pepper
3) Extra virgin olive oil
4) Fresh oregano
5) Lemon juice
6) Garlic

Technique matters; however, the addition of these six ingredien
- Baseline: The primary ingredients in Greek cooking are olive oil, lemon juice, garlic, oregano, and feta cheese. The spices that are commonly used in Greek cook
- Fine-tuned: The primary ingredients in Greek cooking are olive oil, lemon, garlic, oregano, and feta cheese.  These ingredients are used in a variety of dishes, i

**[brainstorming]** What medicinal plants should I grow in my Mid-Atlantic garden?
- Reference: Echinacea
Elder
Bee balm
Lemon balm
Mullein
Burdock
Yarrow
Wood Betony
- Baseline: The Mid-Atlantic region is a diverse area with a wide range of climates and growing conditions. However, there are some medicinal plants that are well
- Fine-tuned: The Mid-Atlantic region of the United States is a temperate climate with four distinct seasons.  The growing season is long enough to grow many medici

**[brainstorming]** What are some ways I could cheer up my friend that just got dumped?
- Reference: Im sorry your friend recently got dumped.  I would ask them if they want to talk about it, or be distracted from it.  If they want to talk about it, I
- Baseline: - I could send them a funny meme
- I could send them a funny gif
- I could send them a funny video
- I could send them a funny picture
- I could send 
- Fine-tuned: 1. Listen to them and let them vent
2. Offer to go out for a drink
3. Offer to go for a walk
4. Offer to go to the movies
5. Offer to go to a comedy s
