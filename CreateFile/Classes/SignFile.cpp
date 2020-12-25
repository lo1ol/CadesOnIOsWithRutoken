//
//  CadesSign.cpp
//  CAdESSample
//
//  Created by Anatoly Belyaev on 19.11.2020.
//

//#include <stdio.h>
#include <iostream>
#include <vector>
#include <CPROCSP/CPROCSP.h>
#include <CPROPKI/cades.h>
#include <CPROPKI/pkiLicense.h>
#include "SignFile.h"

extern bool USE_CACHE_DIR;

bool isLicenseSet = false;

using namespace std;

CSP_BOOL get_certs(PCCERT_CONTEXT** certs, size_t* count)
{
    PCCERT_CONTEXT pUserCert = NULL;
    CSP_BOOL bResult = FALSE;
    DWORD            dwSize = 0;
    CRYPT_KEY_PROV_INFO *pProvInfo = NULL;
    DWORD ret = 0;
    std::vector<PCCERT_CONTEXT> certs_vector = std::vector<PCCERT_CONTEXT>();
    
    HCERTSTORE hCertStore = CertOpenSystemStore(0, "My");
    if(!hCertStore){
        ret = CSP_GetLastError();
        fprintf (stderr, "CertOpenSystemStore failed.");
        goto exit;
    }
    

    while(true){
        pUserCert = CertFindCertificateInStore(hCertStore, X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, 0, CERT_FIND_ANY, 0, pUserCert);
        if(!pUserCert){
            break;
        }
        bResult = CertGetCertificateContextProperty(pUserCert,
                    CERT_KEY_PROV_INFO_PROP_ID, NULL, &dwSize);
        if (bResult) {
            free(pProvInfo);
            pProvInfo = (CRYPT_KEY_PROV_INFO *)malloc(dwSize);
            if (pProvInfo) {
                bResult = CertGetCertificateContextProperty(pUserCert, CERT_KEY_PROV_INFO_PROP_ID, pProvInfo, &dwSize);
                certs_vector.push_back(CertDuplicateCertificateContext(pUserCert));
            }
        }
    }
    
    free(pProvInfo);
    *certs = (PCCERT_CONTEXT*) malloc(sizeof(certs_vector[0])* *count);
    if (!certs) {
        goto close_cert_store;
    }
    memcpy(*certs, certs_vector.data(), sizeof(certs_vector[0])*certs_vector.size());
    *count=certs_vector.size();
    
    ret = 1;
close_cert_store:
    // Закрываем хранилище
    if (!CertCloseStore(hCertStore, 0)) {
        free(*certs);
        *certs = nullptr;
        cout << "Certificate store handle was not closed." << endl;
        return 0;
    }
    
exit:
    return ret;
}

// Функция получения OID алгоритма хеширования по сертификату
static const char* GetHashOid(const PCCERT_CONTEXT pCert) {
    const char *pKeyAlg = pCert->pCertInfo->SubjectPublicKeyInfo.Algorithm.pszObjId;
    if (strcmp(pKeyAlg, szOID_CP_GOST_R3410EL) == 0)
    {
        return szOID_CP_GOST_R3411;
    }
    else if (strcmp(pKeyAlg, szOID_CP_GOST_R3410_12_256) == 0)
    {
        return szOID_CP_GOST_R3411_12_256;
    }
    else if (strcmp(pKeyAlg, szOID_CP_GOST_R3410_12_512) == 0)
    {
        return szOID_CP_GOST_R3411_12_512;
    }
    return NULL;
}

static void setLicense() {
    
    if (isLicenseSet) {
        return;
    }
    
    if (setPkiLicense(L"0A202-U0030-00ECW-RRLMF-UU2WK")) {
        cout << "Error setting OCSP License" << endl;
    }
    if (setPkiLicense(L"TA200-G0030-00ECW-RRLNE-BTDVV")) {
        cout << "Error setting TSP License" << endl;
    }
    isLicenseSet = true;
}

const wchar_t *GetWC(const char *c)
{
    const size_t cSize = strlen(c)+1;
    wchar_t* wc = new wchar_t[cSize];
    mbstowcs (wc, c, cSize);

    return wc;
}

CSP_BOOL do_low_sign(const uint8_t* msg, size_t msg_size, const PCCERT_CONTEXT context, const char* tsp, char** signature)
{
    const LPCWSTR w_tsp = GetWC(tsp);
    DWORD dwLen = 0;
    DWORD rv = 0;
    
    CRYPT_SIGN_MESSAGE_PARA signPara = {sizeof(signPara)};
    CADES_SIGN_PARA cadesSignPara = {sizeof(cadesSignPara)};
    CADES_SERVICE_CONNECTION_PARA tspConnectionPara = {sizeof(tspConnectionPara)};
    CADES_SIGN_MESSAGE_PARA para = {sizeof(para)};
    const unsigned char *pbToBeSigned[] = {msg};
    
    DWORD cbToBeSigned[] = {(DWORD) msg_size};
    CERT_CHAIN_PARA        ChainPara = { sizeof(ChainPara) };
    PCCERT_CHAIN_CONTEXT    pChainContext = NULL;
    PCRYPT_DATA_BLOB pSignedMessage = 0;
    DWORD i;
    
    std::vector<PCCERT_CONTEXT> certs;
    *signature = 0;
    
    setLicense();
    
    // Если сертификат не найден, завершаем работу
    if (!context) {
        goto free_tsp;
    }
    
    // Задаем параметры
    signPara.dwMsgEncodingType = X509_ASN_ENCODING | PKCS_7_ASN_ENCODING;
    signPara.pSigningCert = context;
    signPara.HashAlgorithm.pszObjId = (LPSTR) GetHashOid(context);
    
    cadesSignPara.dwCadesType = CADES_X_LONG_TYPE_1; //Указываем тип проверяемой подписи CADES_BES или CADES_X_LOGNG_TYPE_1
    tspConnectionPara.wszUri = w_tsp;
    cadesSignPara.pTspConnectionPara = &tspConnectionPara;
    
    para.pSignMessagePara = &signPara;
    para.pCadesSignPara = &cadesSignPara;
    
    if (CertGetCertificateChain(
                                NULL,
                                context,
                                NULL,
                                NULL,
                                &ChainPara,
                                0,
                                NULL,
                                &pChainContext)) {
        
        for (i = 0; i < pChainContext->rgpChain[0]->cElement-1; ++i)
        {
            certs.push_back(pChainContext->rgpChain[0]->rgpElement[i]->pCertContext);
        }
    }
    
        
    // Добавляем в сообщение цепочку сертификатов без корневого
    if (certs.size() > 0)
    {
        signPara.cMsgCert = (DWORD)certs.size();
        signPara.rgpMsgCert = &certs[0];
    }
    
    // Создаем подписанное сообщение
    if (!CadesSignMessage(&para, 0, 1, pbToBeSigned, cbToBeSigned, &pSignedMessage)) {
        cout << "CadesSignMessage() failed" << endl;
        goto free_tsp;
    }
    if (pChainContext)
        CertFreeCertificateChain(pChainContext);
    
    if (!CryptBinaryToStringA(pSignedMessage->pbData, pSignedMessage->cbData, CRYPT_STRING_BASE64, nullptr, &dwLen)) {
        cout << "Error in decode signature to base64" << endl;
        goto free_tsp;
    }
    
    *signature = (char *) malloc(dwLen);
    if (!CryptBinaryToStringA(pSignedMessage->pbData, pSignedMessage->cbData, CRYPT_STRING_BASE64, *signature, &dwLen)) {
        free(signature);
        cout << "Error in decode signature to base64" << endl;
        goto free_tsp;
    }
    (*signature)[dwLen] = 0;
    
    // Освобождаем структуру с закодированным подписанным сообщением
    if (!CadesFreeBlob(pSignedMessage)) {
        free(signature);
        cout << "CadesFreeBlob() failed" << endl;
        goto free_tsp;
    }
    
    rv = 1;
    
free_tsp:
    delete[] (w_tsp);

exit:
    return rv;
}

DWORD do_low_verify(const char* signature)
{
    // Задаем параметры проверки
    CRYPT_VERIFY_MESSAGE_PARA cryptVerifyPara = { sizeof(cryptVerifyPara) };
    cryptVerifyPara.dwMsgAndCertEncodingType = X509_ASN_ENCODING | PKCS_7_ASN_ENCODING;
    
    CADES_VERIFICATION_PARA cadesVerifyPara = { sizeof(cadesVerifyPara) };
    cadesVerifyPara.dwCadesType = CADES_X_LONG_TYPE_1; // Указываем тип проверяемой подписи CADES_BES или CADES_X_LOGNG_TYPE_1
    
    CADES_VERIFY_MESSAGE_PARA verifyPara = { sizeof(verifyPara) };
    verifyPara.pVerifyMessagePara = &cryptVerifyPara;
    verifyPara.pCadesVerifyPara = &cadesVerifyPara;
    
    PCADES_VERIFICATION_INFO pVerifyInfo = 0;
    PCRYPT_DATA_BLOB pContent = 0;
    
    DWORD dwLen = 0;
    if (!CryptStringToBinaryA(signature, (DWORD)strlen(signature), CRYPT_STRING_BASE64_ANY, NULL, &dwLen, NULL, NULL)) {
        cout << "Error in decode from base64" << endl;
        return 0;
    }
    vector<unsigned char> message(dwLen);
    if (!CryptStringToBinaryA(signature, (DWORD)strlen(signature), CRYPT_STRING_BASE64_ANY, &message[0], &dwLen, NULL, NULL)) {
        cout << "Error in decode from base64" << endl;
        return 0;
    }
    message.resize(dwLen);
    
    // Проверяем подпись
    if (!CadesVerifyMessage(&verifyPara, 0, &message[0], (DWORD)message.size(), &pContent, &pVerifyInfo))
    {
        CadesFreeVerificationInfo(pVerifyInfo);
        cout << "CadesVerifyMessage() failed" << endl;
        return 0;
    }
    
    // Выводим результат проверки
    if (pVerifyInfo->dwStatus != CADES_VERIFY_SUCCESS)
        cout << "Message is not verified successfully." << endl;
    else
        cout << "Message verified successfully." << endl;
    
    // Освобождаем ресурсы
    if (!CadesFreeVerificationInfo(pVerifyInfo))
    {
        CadesFreeBlob(pContent);
        cout << "CadesFreeVerificationInfo() failed" << endl;
        return 0;
    }
    
    if (!CadesFreeBlob(pContent))
    {
        cout << "CadesFreeBlob() failed" << endl;
        return 0;
    }
    
    return  1;
}

