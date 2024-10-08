#' @import reticulate
#' @import dplyr
#' @import stringr
#' @export

Llama3_input <- function(input,topgenenumber, species, tissuename) {
  reticulate::py_run_string("
import requests
import json

llama_payload = {
    'user_id': 'python',
    'messages': [],
    'disable_search': False,
    'enable_citation': False
}

def add_llama_message(role, content):
    # 将新消息添加到消息列表
    message = {
        'role': role,
        'content': content
    }
    llama_payload['messages'].append(message)


def get_access_llama3_token(Llama3_api_key, Llama3_secret_key):
    url = 'https://aip.baidubce.com/oauth/2.0/token'
    params = {'grant_type': 'client_credentials', 'client_id': Llama3_api_key, 'client_secret': Llama3_secret_key}
    return str(requests.post(url, params=params).json().get('access_token'))

access_llama3_token = get_access_llama3_token(Llama3_api_key, Llama3_secret_key)
url = 'https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/llama_3_70b?access_token=' + access_llama3_token


def chat_with_llama3(user_input):
    add_llama_message('user', user_input)
    headers = {'Content-Type': 'application/json'}
    json_llama_payload = json.dumps(llama_payload)
    response = requests.request('POST', url, headers=headers, data=json_llama_payload)
    result = response.json().get('result')

    add_llama_message('assistant', result)
    return result
")
  top_markers <- input %>% dplyr::group_by(cluster) %>% dplyr::top_n(n = topgenenumber, wt = avg_log2FC)
  cluster_genes <- top_markers %>%
    dplyr::group_by(cluster) %>%
    dplyr::summarise(genes = paste(gene, collapse=", ")) %>%
    dplyr::ungroup()
  row_prefixes <- paste("row", 1:nrow(cluster_genes), ":", sep="")
  formatted_rows <- paste(row_prefixes, cluster_genes$genes, sep=" ")
  formatted_output <- paste(formatted_rows, collapse="; ")
  user_input <-paste('ldentify cell types of', species, tissuename, 'using the following markers.Identify one cell type for each of the following rows of marker genes, providing only one cell type.Just reply to the cell type, no need to reply to the reasoning section or explanation section:\n', formatted_output, 'Reply in the following format:
1: xx
2: xx
N: xx
N is the line number, xx is a phrase that only includes cell types, such as pluripotent stem cells and smooth muscle cells. Do not add additional text!Use "undefined" as a substitute if identification cannot be made.')
  result <- py$chat_with_llama3(user_input)
  print(result)
  return(result)
}
