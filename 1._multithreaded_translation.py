import os
import logging
import pandas as pd
from multiprocessing.pool import ThreadPool
from deep_translator import GoogleTranslator
from warnings import simplefilter
import argparse

# Example usage: 
#python "multithreaded_translation.py" --input_path "tweets.csv" --output_path "path_to_where_the_file_should_be_stored" --num_threads 4 --language "de"

# Suppress pandas FutureWarnings
simplefilter(action='ignore')

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def translate_text(text, target_language):
    """Translates text using GoogleTranslator."""
    try:
        return GoogleTranslator(source='auto', target=target_language).translate(text)
    except Exception as e:
        logging.error(f"Translation failed for text: {text[:30]}... | Error: {e}")
        return 'no translation'

def translate_dataframe_segment(df_segment, thread_name, save_path, target_language):
    """Translates a segment of the dataframe and saves interim results periodically."""
    translated_texts = []
    checkpoint_interval = 5
    counter = 0
    for idx, row in df_segment.iterrows():
        translated_texts.append(translate_text(row.text, target_language))
        counter += 1
        if (counter) % checkpoint_interval == 0:
            logging.info(f"{thread_name}: Translated {counter} tweets")
    
    df_segment['text_translated'] = translated_texts
    #df_segment.to_csv(os.path.join(save_path, f'data_translated_{thread_name}.csv'), index=False)
    return df_segment

def translate_dataframe(df, num_threads, parent_dir, target_language='de'):
    """Splits the dataframe and translates it using multiple threads."""
    logging.info("Starting translation process...")
    save_dir = os.path.join(parent_dir, "dfs_translated")
    os.makedirs(save_dir, exist_ok=True)
    
    # Split dataframe into chunks for multithreading
    chunk_size = len(df) // num_threads
    df_chunks = [df.iloc[i * chunk_size : (i + 1) * chunk_size] for i in range(num_threads)]
    
    # Adjust last chunk to avoid data loss
    df_chunks[-1] = pd.concat([df_chunks[-1], df.iloc[num_threads * chunk_size:]])
    
    thread_names = [f'Thread_{i+1}' for i in range(num_threads)]
    save_paths = [os.path.join(save_dir, f'sub_dfs_translated_{i+1}') for i in range(num_threads)]
    
    for path in save_paths:
        os.makedirs(path, exist_ok=True)
    
    pool = ThreadPool(num_threads)
    results = [pool.apply_async(translate_dataframe_segment, args=(df_chunks[i], thread_names[i], save_paths[i], target_language)) for i in range(num_threads)]
    
    pool.close()
    pool.join()
    
    # Combine translated results
    translated_dfs = [res.get() for res in results]
    translated_df = pd.concat(translated_dfs).reset_index(drop=True)
    
    output_file = os.path.join(parent_dir, 'df_translated.csv')
    translated_df.to_csv(output_file, index=False)
    logging.info(f"Translation completed. File saved at {output_file}")
    
    return translated_df

def main():
    parser = argparse.ArgumentParser(description="Translate tweets from a CSV file.")
    parser.add_argument("--input_path", type=str, required=True, help="Path to the input CSV file containing tweets.")
    parser.add_argument("--output_path", type=str, required=True, help="Path to store the translated CSV file.")
    parser.add_argument("--num_threads", type=int, default=4, help="Number of threads for parallel translation.")
    parser.add_argument("--language", type=str, default='de', help="Target language for translation (default: 'de').")
    
    args = parser.parse_args()
    
    df = pd.read_csv(args.input_path)
    translate_dataframe(df, args.num_threads, args.output_path, args.language)

if __name__ == "__main__":
    print('Starting')
    main()
